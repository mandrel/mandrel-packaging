#!/usr/bin/env bash

if [[ "${VERBOSE}" == "true" ]]; then
    set -x
    VERBOSE_BUILD=--verbose
    VERBOSE_MX=-v
fi

MX_HOME=${MX_HOME:-/opt/mx}
JAVA_HOME=${JAVA_HOME:-/opt/jdk}
MANDREL_REPO=${MANDREL_REPO:-/tmp/mandrel}
MANDREL_HOME=${MANDREL_HOME:-/opt/mandrelJDK}
MAVEN_REPO=${MAVEN_REPO:-~/.m2/repository}
if [[ "${SKIP_CLEAN}" == "true" ]]; then
    SKIP_CLEAN_FLAG=--skipClean
fi
# tarxz or tar.gz
TAR_SUFFIX=${TAR_SUFFIX:-tar.gz}

pushd ${MANDREL_REPO}/substratevm
MANDREL_VERSION=${MANDREL_VERSION:-$((git describe 2>/dev/null || git rev-parse --short HEAD) | sed 's/mandrel-//')}
popd
MANDREL_VERSION_UNTIL_SPACE="$( echo ${MANDREL_VERSION} | sed -e 's/\([^ ]*\).*/\1/;t' )"
MAVEN_ARTIFACTS_VERSION="${MANDREL_VERSION_UNTIL_SPACE}.redhat-00001"
ARCHIVE_NAME="mandrel-java11-linux-amd64-${MANDREL_VERSION_UNTIL_SPACE}.${TAR_SUFFIX}"

### Build Mandrel
## JVM bits
basename="$(dirname $0)"
${JAVA_HOME}/bin/java -ea $basename/src/build.java ${VERBOSE_BUILD} --version "${MAVEN_ARTIFACTS_VERSION}" --maven-local-repository ${MAVEN_REPO} --mx-home ${MX_HOME} --mandrel-home ${MANDREL_REPO} ${SKIP_CLEAN_FLAG}

## native bits
pushd ${MANDREL_REPO}/substratevm
${MX_HOME}/mx ${VERBOSE_MX} build --projects com.oracle.svm.native.libchelper
${MX_HOME}/mx ${VERBOSE_MX} build --projects com.oracle.svm.native.jvm.posix
${MX_HOME}/mx ${VERBOSE_MX} build --only native-image.image-bash
popd

### Copy default JDK
rm -rf ${MANDREL_HOME}
cp -r -L ${JAVA_HOME} ${MANDREL_HOME}

### Copy needed jars

mkdir -p ${MANDREL_HOME}/lib/svm/builder
cp ${MAVEN_REPO}/org/graalvm/nativeimage/svm/${MAVEN_ARTIFACTS_VERSION}/svm-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/svm/builder/svm.jar
cp ${MAVEN_REPO}/org/graalvm/nativeimage/svm/${MAVEN_ARTIFACTS_VERSION}/svm-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/svm/builder/svm.src.zip
cp ${MAVEN_REPO}/org/graalvm/nativeimage/pointsto/${MAVEN_ARTIFACTS_VERSION}/pointsto-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/svm/builder/pointsto.jar
cp ${MAVEN_REPO}/org/graalvm/nativeimage/pointsto/${MAVEN_ARTIFACTS_VERSION}/pointsto-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/svm/builder/pointsto.src.zip
cp ${MAVEN_REPO}/org/graalvm/nativeimage/objectfile/${MAVEN_ARTIFACTS_VERSION}/objectfile-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/svm/builder/objectfile.jar
cp ${MAVEN_REPO}/org/graalvm/nativeimage/objectfile/${MAVEN_ARTIFACTS_VERSION}/objectfile-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/svm/builder/objectfile.src.zip

mkdir ${MANDREL_HOME}/lib/graalvm
cp ${MAVEN_REPO}/org/graalvm/nativeimage/svm-driver/${MAVEN_ARTIFACTS_VERSION}/svm-driver-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/graalvm/svm-driver.jar
cp ${MAVEN_REPO}/org/graalvm/nativeimage/svm-driver/${MAVEN_ARTIFACTS_VERSION}/svm-driver-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/graalvm/svm-driver.src.zip

## The following jars are not included in the GraalJDK created by `mx --components="Native Image" build`
mkdir ${MANDREL_HOME}/lib/jvmci
cp ${MAVEN_REPO}/org/graalvm/sdk/graal-sdk/${MAVEN_ARTIFACTS_VERSION}/graal-sdk-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/jvmci/graal-sdk.jar
cp ${MAVEN_REPO}/org/graalvm/sdk/graal-sdk/${MAVEN_ARTIFACTS_VERSION}/graal-sdk-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/jvmci/graal-sdk.src.zip
cp ${MAVEN_REPO}/org/graalvm/compiler/compiler/${MAVEN_ARTIFACTS_VERSION}/compiler-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/jvmci/graal.jar
cp ${MAVEN_REPO}/org/graalvm/compiler/compiler/${MAVEN_ARTIFACTS_VERSION}/compiler-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/jvmci/graal.src.zip

mkdir ${MANDREL_HOME}/lib/truffle
cp ${MAVEN_REPO}/org/graalvm/truffle/truffle-api/${MAVEN_ARTIFACTS_VERSION}/truffle-api-${MAVEN_ARTIFACTS_VERSION}.jar ${MANDREL_HOME}/lib/truffle/truffle-api.jar
cp ${MAVEN_REPO}/org/graalvm/truffle/truffle-api/${MAVEN_ARTIFACTS_VERSION}/truffle-api-${MAVEN_ARTIFACTS_VERSION}-sources.jar ${MANDREL_HOME}/lib/truffle/truffle-api.src.zip

### Docs
cp ${MANDREL_REPO}/LICENSE ${MANDREL_HOME}
cp ${MANDREL_REPO}/THIRD_PARTY_LICENSE.txt ${MANDREL_HOME}
cp ${MANDREL_REPO}/README-Mandrel.md ${MANDREL_HOME}/README.md
cp ${MANDREL_REPO}/SECURITY.md ${MANDREL_HOME}

### Copy native bits
mkdir -p ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64/include
cp ${MANDREL_REPO}/substratevm/src/com.oracle.svm.native.libchelper/include/amd64cpufeatures.h ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64/include
cp ${MANDREL_REPO}/substratevm/src/com.oracle.svm.native.libchelper/include/aarch64cpufeatures.h ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64/include
cp ${MANDREL_REPO}/substratevm/src/com.oracle.svm.libffi/include/svm_libffi.h ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64/include
cp ${MANDREL_REPO}/truffle/src/com.oracle.truffle.nfi.native/include/trufflenfi.h ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64/include
cp ${MANDREL_REPO}/substratevm/mxbuild/linux-amd64/src/com.oracle.svm.native.libchelper/amd64/liblibchelper.a ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64
cp ${MANDREL_REPO}/substratevm/mxbuild/linux-amd64/src/com.oracle.svm.native.jvm.posix/amd64/libjvm.a ${MANDREL_HOME}/lib/svm/clibraries/linux-amd64
mkdir ${MANDREL_HOME}/lib/svm/bin
cp ${MANDREL_REPO}/sdk/mxbuild/linux-amd64/native-image.image-bash/native-image ${MANDREL_HOME}/lib/svm/bin/native-image
## Create symbolic link in bin
ln -s ../lib/svm/bin/native-image ${MANDREL_HOME}/bin/native-image

### Fix native-image launcher
sed -i -e "s!EnableJVMCI!EnableJVMCI -Dorg.graalvm.version=\"${MANDREL_VERSION} (Mandrel Distribution)\" --upgrade-module-path \${location}/../../jvmci/graal.jar --add-modules \"org.graalvm.truffle,org.graalvm.sdk\" --module-path \${location}/../../truffle/truffle-api.jar:\${location}/../../jvmci/graal-sdk.jar!" \
    "${MANDREL_HOME}/lib/svm/bin/native-image"

### Create tarball
if [[ "${TAR_SUFFIX}" == "tar.gz" ]]; then
  tar -czf "${ARCHIVE_NAME}" -C $(dirname ${MANDREL_HOME}) $(basename ${MANDREL_HOME})
elif [[ "${TAR_SUFFIX}" == "tarxz" ]]; then
  Z_OPT=-9e tar cJf "${ARCHIVE_NAME}" -C $(dirname ${MANDREL_HOME}) $(basename ${MANDREL_HOME})
else
  echo "Unknown archive suffix ${TAR_SUFFIX}"
  exit 1
fi
