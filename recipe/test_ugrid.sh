#!/usr/bin/env bash
set -euxo pipefail

# Regression test for patches/0002-mesh-hash-signed-conversion.patch: run
# upstream's own UGRID test (a cube-sphere mesh, longitudes in [-180, 180]) with
# its node and edge fields switched on. Without the patch this segfaults on
# aarch64 in CMesh::createMeshEpsilon; with it, it writes all three meshes.
cp inputs/ugrid_test/iodef.xml iodef-cells.xml
sed -e 's/field_ref="field_node" enabled="false"/field_ref="field_node" enabled="true"/' \
    -e 's/field_ref="field_edge" enabled="false"/field_ref="field_edge" enabled="true"/' \
    inputs/ugrid_test/iodef.xml > iodef-all.xml
grep -q 'field_ref="field_node" enabled="true"' iodef-all.xml
grep -q 'field_ref="field_edge" enabled="true"' iodef-all.xml

case "${target_platform:-$(uname -s)}" in
  osx-*|Darwin) CXX_RT_LIB="-lc++" ;;
  *)            CXX_RT_LIB="-lstdc++" ;;
esac

# The test declares its mesh coordinates as default REAL and passes them to
# XIOS's double-precision interfaces; upstream builds it with real-8.
mpif90 -fdefault-real-8 -ffree-line-length-none -I"${PREFIX}/include" \
  src/test/test_ugrid.f90 -o test_ugrid \
  -L"${PREFIX}/lib" -Wl,-rpath,"${PREFIX}/lib" \
  -lxios -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 ${CXX_RT_LIB}

# Attached mode (using_server=false in iodef.xml), one rank: a singleton
# MPI_Init, so no launcher is needed. Upstream's own config (cells only) first,
# so a failure says whether it is XIOS at all or the node/edge meshes.
for case in cells all; do
  mkdir "run-$case"
  cp "iodef-$case.xml" "run-$case/iodef.xml"
  ( cd "run-$case" && ../test_ugrid )
  test -s "run-$case/output.nc"
  echo "test_ugrid $case: OK"
done

echo "XIOS_UGRID_TEST_OK"
