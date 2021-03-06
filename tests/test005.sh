#!/usr/bin/env bash
#
# Copyright (c) STMicroelectronics 2014
#
# This file is part of repo-mirror.
#
# repo-mirror is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License v2.0
# as published by the Free Software Foundation
#
# repo-mirror is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# v2.0 along with repo-mirror. If not, see <http://www.gnu.org/licenses/>.
#

# unitary test

source `dirname $0`/common.sh

TEST_CASE="repo-mirror expected failure of parallel updates without lock"

# Skip python 3 not supported by repo 1
! is_python3_repo1 || skip "python 3 not supported by repo 1"

# Generate a repo/git structure with a project1.git
$SRCDIR/tests/scripts/generate_repo.sh repos-1 project1

# Generate another repo/git structure with also a project1.git,
# hence will generate an aliased repo in the mirrors
$SRCDIR/tests/scripts/generate_repo.sh repos-2 project1

# Generate template script for extracting a manifest, argument is 1 or 2
# for extracting  either repo tree 1 or 2
# Set locking scheme to none for this test
cat >repo-test.sh <<EOF
#!/usr/bin/env bash
set -eu
set -o pipefail

id=\${1?}
mkdir -p repo-mirrors
mkdir -p test-repos-\$id
pushd test-repos-\$id >/dev/null
$REPO_MIRROR -m "$TMPTEST/repo-mirrors" -d -q --internal-locking=none -- init -u file://"$TMPTEST"/repos-\$id/manifests.git </dev/null
repo sync
[ -f project1/README ]

# Verify that local project1 have an alternate pointing to default mirror
# and that the HEAD commit object is not local and is in the alternate
[ -f project1/.git/objects/info/alternates ]
[ "\$(<project1/.git/objects/info/alternates)" = "$TMPTEST/repo-mirrors/default/repos/project1.git/objects" ]
obj1=\$(env GIT_DIR=project1/.git git rev-parse HEAD)
[ ! -f project1/.git/objects/\${obj1::2}/\${obj1:2} ]
[ -f "$TMPTEST"/repo-mirrors/default/repos/project1.git/objects/\${obj1::2}/\${obj1:2} ]
popd >/dev/null
EOF
chmod +x repo-test.sh

# Run full repo-mirror init/sync in parallel on both repo trees.
# This should generate a failure due to a race condition on mirrored gits update.
res=0
SHELL=/bin/sh parallel -j 16 -u "echo {} && ./repo-test.sh {2} >repo-test-{1}-{2}.log 2>&1" ::: $(seq 1 8) ::: 1 2 || res=$?
[ $res != 0 ]
