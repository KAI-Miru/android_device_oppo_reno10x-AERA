#!/usr/bin/env bash
set -euo pipefail
runner_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
device_repo=$(cd -- "${AERA_DEVICE_DIR:?Set AERA_DEVICE_DIR to the device checkout}" && pwd)
build_root=${AERA_SOURCE_DIR:?Set AERA_SOURCE_DIR to a dedicated source directory}
artifact_root=${AERA_ARTIFACT_DIR:?Set AERA_ARTIFACT_DIR}
jobs=${BUILD_JOBS:-2}
# Catch missing BusyBox packaging inputs before syncing and compiling Android.
python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1] + "/tools"); from verify_busybox import verify_tree; verify_tree(sys.argv[1])' "$device_repo"
mkdir -p "$build_root" "$artifact_root"
trap 'df -h "$build_root" | tee "$artifact_root/source-capacity.txt"' EXIT
git -C "$device_repo" rev-parse HEAD > "$artifact_root/device-tree.txt"
git -C "$runner_root" rev-parse HEAD > "$artifact_root/runner-tree.txt"
manifest_revision=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["manifest_commit"])' "$device_repo/sources.lock.json")
aosp_revision=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["aosp_revision"])' "$device_repo/sources.lock.json")
# Upstream still declares SSH remotes. All pinned dependencies are public;
# HTTPS needs no user PAT or SSH key, and no token is written into the manifest.
git_config="$build_root/.aera-ci.gitconfig"
export GIT_CONFIG_GLOBAL="$git_config"
git config --file "$git_config" user.name 'AERA CI'
git config --file "$git_config" user.email 'aera-ci@users.noreply.github.com'
git config --file "$git_config" url."https://github.com/".insteadOf "ssh://git@github.com/"
git config --file "$git_config" http.lowSpeedLimit 1024
git config --file "$git_config" http.lowSpeedTime 120
cd "$build_root"
# Resume a retained checkout without keeping duplicate compressed copies of
# already checked-out source files. Pinned commits and trees remain available.
du -h --max-depth=1 "$build_root" | sort -h | tee "$artifact_root/source-footprint.txt"
python3 "$runner_root/tools/compact_checkout.py" "$build_root"
source_lock=$(sha256sum "$device_repo/sources.lock.json" "$runner_root/tools/prepare_manifest.py" "$runner_root/tools/prepare_checkout.py" "$runner_root/tools/complete_snapshot.py" | sha256sum | cut -d' ' -f1)
if [[ ! -f .aera-source-lock ]] || [[ $(cat .aera-source-lock) != "$source_lock" ]]; then
    repo init -u https://github.com/AERA-Recovery/android_manifest.git -b "$manifest_revision" --depth=1 --no-clone-bundle --no-use-superproject
    python3 "$runner_root/tools/prepare_manifest.py" "$device_repo/sources.lock.json" .repo/local_manifests/reno10x-pins.xml
    repo manifest -o "$artifact_root/source-plan.xml"
    exclusions=$(python3 "$runner_root/tools/prepare_checkout.py" exclusions "$artifact_root/source-plan.xml")
    repo init -u https://github.com/AERA-Recovery/android_manifest.git -b "$manifest_revision" --depth=1 --no-clone-bundle --no-use-superproject --partial-clone --clone-filter=blob:none --partial-clone-exclude="$exclusions"
    bash "$runner_root/ci/run-with-capacity.sh" repo sync -v -n -c --force-sync --no-clone-bundle --no-tags --optimized-fetch --fail-fast --jobs-network=8
    bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 30m python3 "$runner_root/tools/prepare_checkout.py" configure "$build_root" --lock "$device_repo/sources.lock.json"
    checkout_status=0
    for checkout_attempt in 1 2 3 4; do
        checkout_status=0
        bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 30m repo sync -v -l -c --force-sync --fail-fast --jobs-checkout="$jobs" || checkout_status=$?
        python3 "$runner_root/tools/compact_checkout.py" "$build_root"
        (( checkout_status == 75 || checkout_status == 124 )) || break
        free_kib=$(df -Pk "$build_root" | awk 'NR==2 {print $4}')
        (( free_kib > 6 * 1024 * 1024 )) || break
    done
    if (( checkout_status == 75 )); then
        exit 75
    elif (( checkout_status == 76 )); then
        exit 76
    elif (( checkout_status != 0 )); then
        df -h "$build_root"
        du -sh .repo prebuilts
        # repo's worktree initializer hides the underlying read-tree failure.
        # Repeat affected tool checkouts directly so the Git error is visible.
        for diagnostic_project in prebuilts/clang/host/linux-x86 prebuilts/rust prebuilts/sdk; do
            if [[ "$diagnostic_project" != prebuilts/sdk ]]; then
                bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 30m python3 \
                    "$runner_root/tools/complete_snapshot.py" "$build_root" "$diagnostic_project" --require-full --revision "refs/tags/$aosp_revision"
            fi
            bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 15m git --git-dir="$build_root/.repo/projects/$diagnostic_project.git" \
                --work-tree="$build_root/$diagnostic_project" read-tree --reset -u -v HEAD
        done
        bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 30m repo sync -v -l -c --force-sync --fail-fast --jobs-checkout=1
    fi
    df -h "$build_root"
    du -sh .repo prebuilts
    printf '%s\n' "$source_lock" > .aera-source-lock
fi
mkdir -p device/oppo/reno10x
rsync -rcp --delete --exclude='.git' --exclude='reports' --exclude='out' --exclude='__pycache__' "$device_repo/" device/oppo/reno10x/
repo manifest -r -o "$artifact_root/source-manifest.xml"
for java8_jar in rt jce; do
    test -s "prebuilts/jdk/jdk8/linux-x86/jre/lib/$java8_jar.jar" || {
        echo "Missing pinned JDK 8 bootclasspath: $java8_jar.jar" >&2
        exit 1
    }
done
python3 "$runner_root/tools/prepare_build.py" "$build_root" "$artifact_root" "$device_repo/sources.lock.json"
recovery_revision=$(python3 -c 'import json,sys; print(next(p["commit"] for p in json.load(open(sys.argv[1]))["projects"] if p["path"] == "bootable/recovery"))' "$device_repo/sources.lock.json")
# Native version checks must be able to read original blobs without fetching
# from inside the network-isolated Android build sandbox.
bash "$runner_root/ci/run-with-capacity.sh" timeout --kill-after=30s 15m python3 \
    "$runner_root/tools/complete_snapshot.py" "$build_root" bootable/recovery --revision "$recovery_revision" --require-objects
# Confirm all source pins before building.
python3 - "$device_repo/sources.lock.json" <<'PY'
import json, subprocess, sys
for project in json.load(open(sys.argv[1]))['projects']:
    actual = subprocess.check_output(['git', '-C', project['path'], 'rev-parse', 'HEAD'], text=True).strip()
    assert actual == project['commit'], (project['path'], actual, project['commit'])
PY
bash "$runner_root/ci/run-with-capacity.sh" bash "$runner_root/ci/compile.sh"
image=out/target/product/reno10x/recovery.img
test -s "$image"
python3 "$runner_root/tools/verify_test_image.py" "$device_repo" "$image" > "$artifact_root/image-verification.json"
python3 external/avb/avbtool.py add_hash_footer --image "$image" --partition_name recovery --partition_size 67108864 --hash_algorithm sha256 --algorithm NONE
test "$(stat -c %s "$image")" = 67108864
python3 external/avb/avbtool.py verify_image --image "$image" > "$artifact_root/avb-verification.txt"
cp "$image" "$artifact_root/AERA-reno10x-metadata-upgrade-recovery.img"
cd "$artifact_root"
sha256sum AERA-reno10x-metadata-upgrade-recovery.img > SHA256SUMS
