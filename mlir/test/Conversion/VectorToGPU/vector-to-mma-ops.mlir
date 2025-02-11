// RUN: mlir-opt %s -pass-pipeline="builtin.module(func.func(convert-vector-to-gpu),canonicalize)" | FileCheck %s

#map0 = affine_map<(d0, d1) -> (d1, d0)>
#map1 = affine_map<(d0, d1, d2) -> (d0, d2)>
#map2 = affine_map<(d0, d1, d2) -> (d1, d2)>
#map3 = affine_map<(d0, d1, d2) -> (d0, d1)>
#map4 = affine_map<(d0) -> (d0, 0)>
#map5 = affine_map<(d0, d1) -> (d0, d1)>

// CHECK-LABEL: func @matmul
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_cst
//   CHECK-DAG:   %[[CST:.+]] = arith.constant 0.000000e+00 : f16
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_constant_matrix %[[CST]] : !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_cst(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %cst_0 : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_broadcast
//  CHECK-SAME:   (%{{.*}}: memref<16x16xf16>, %{{.*}}: memref<16x16xf16>, %{{.*}}: memref<16x16xf16>, %[[F:.*]]: f16)
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_constant_matrix %[[F]] : !gpu.mma_matrix<16x16xf16, "COp">
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_broadcast(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>, %arg2: memref<16x16xf16>, %f: f16) {
  %C = vector.broadcast %f : f16 to vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_loop
//       CHECK:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 128 : index} : memref<128x128xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[ACC:.+]] = scf.for {{.*}} iter_args(%[[ACC1:.+]] = %[[C]]) -> (!gpu.mma_matrix<16x16xf16, "COp">) {
//   CHECK-DAG:     %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 128 : index} : memref<128x128xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:     %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 128 : index} : memref<128x128xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//  CHECK-NEXT:     %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[ACC1]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//  CHECK-NEXT:     scf.yield %[[D]] : !gpu.mma_matrix<16x16xf16, "COp">
//  CHECK-NEXT:   }
//  CHECK-NEXT:   gpu.subgroup_mma_store_matrix %[[ACC]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 128 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<128x128xf16>
func.func @matmul_loop(%arg0: memref<128x128xf16>, %arg1: memref<128x128xf16>, %arg2: memref<128x128xf16>) {
  %c0 = arith.constant 0 : index
  %c128 = arith.constant 128 : index
  %c32 = arith.constant 32 : index
  %cst = arith.constant 0.000000e+00 : f16
  %C = vector.transfer_read %arg2[%c0, %c0], %cst {in_bounds = [true, true]} : memref<128x128xf16>, vector<16x16xf16>
  %14 = scf.for %arg17 = %c0 to %c128 step %c32 iter_args(%arg18 = %C) -> (vector<16x16xf16>) {
    %17 = vector.transfer_read %arg0[%c0, %arg17], %cst {in_bounds = [true, true]} : memref<128x128xf16>, vector<16x16xf16>
    %18 = vector.transfer_read %arg1[%arg17, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<128x128xf16>, vector<16x16xf16>
    %19 = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %17, %18, %arg18 : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
    scf.yield %19 : vector<16x16xf16>
  }
  vector.transfer_write %14, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<128x128xf16>
  return
}

// CHECK-LABEL: func @matmul_fused_elementwise
//   CHECK-DAG:   %[[CST_0:.+]] = arith.constant 0.000000e+00 : f16
//   CHECK-DAG:   %[[CST_1:.+]] = arith.constant 1.000000e+00 : f16
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C0:.+]] = gpu.subgroup_mma_constant_matrix %[[CST_0]] : !gpu.mma_matrix<16x16xf16, "COp">
//   CHECK-DAG:   %[[C1:.+]] = gpu.subgroup_mma_constant_matrix %[[CST_1]] : !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C0]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[E:.+]] = gpu.subgroup_mma_elementwise addf %[[D]], %[[C1]] : (!gpu.mma_matrix<16x16xf16, "COp">, !gpu.mma_matrix<16x16xf16, "COp">) -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[E]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_fused_elementwise(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %cst_1 = arith.constant dense<1.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %cst_0 : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  %E = arith.addf %D, %cst_1 : vector<16x16xf16>
  vector.transfer_write %E, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_fused_broadcast
//   CHECK-DAG:   %[[CST_0:.+]] = arith.constant 0.000000e+00 : f16
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C0:.+]] = gpu.subgroup_mma_constant_matrix %[[CST_0]] : !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C0]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[E:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}] {leadDimension = 0 : index} : memref<16x16x16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[F:.+]] = gpu.subgroup_mma_elementwise divf %[[D]], %[[E]] : (!gpu.mma_matrix<16x16xf16, "COp">, !gpu.mma_matrix<16x16xf16, "COp">) -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[F]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_fused_broadcast(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>,
  %arg2: memref<16x16xf16>, %arg3: memref<16x16x16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %cst_0 : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  %E = vector.transfer_read %arg3[%c0, %c0, %c0, %c0], %cst
    {in_bounds = [true, true], permutation_map = affine_map<(d0, d1, d2, d3)->(0, d3)>}
    : memref<16x16x16x16xf16>, vector<16x16xf16>
  %F = arith.divf %D, %E : vector<16x16xf16>
  vector.transfer_write %F, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_3Dmemref
//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 16 : index} : memref<2x16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]]] {leadDimension = 0 : index} : memref<16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 16 : index} : memref<2x16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<2x16x16xf16>
func.func @matmul_3Dmemref(%arg0: memref<2x16x16xf16>, %arg1: memref<16xf16>, %arg2: memref<2x16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0, %c0], %cst {in_bounds = [true, true]} : memref<2x16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0], %cst {permutation_map = #map4, in_bounds = [true, true]} : memref<16xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0, %c0], %cst {in_bounds = [true, true]} : memref<2x16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<2x16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_memref_strided
//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 32 : index} : memref<2x16x16xf16, #{{.*}}> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]]] {leadDimension = 0 : index} : memref<16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 16 : index} : memref<2x16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%[[C0]], %[[C0]], %[[C0]]] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<2x16x16xf16>
func.func @matmul_memref_strided(%arg0: memref<2x16x16xf16, affine_map<(d0, d1, d2) -> (d0 * 512 + d1 * 32 + d2)>>, %arg1: memref<16xf16>, %arg2: memref<2x16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0, %c0], %cst {in_bounds = [true, true]} : memref<2x16x16xf16, affine_map<(d0, d1, d2) -> (d0 * 512 + d1 * 32 + d2)>>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0], %cst {permutation_map = #map4, in_bounds = [true, true]} : memref<16xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0, %c0], %cst {in_bounds = [true, true]} : memref<2x16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<2x16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_transposed
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index, transpose} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_transposed(%arg0: memref<16x16xf16>, %arg1: memref<16x16xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {permutation_map = #map5, in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_transposed_broadcasted_1d
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}] {leadDimension = 0 : index, transpose} : memref<16xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}] {leadDimension = 0 : index} : memref<16xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_transposed_broadcasted_1d(%arg0: memref<16xf16>, %arg1: memref<16xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0], %cst {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (d0, 0)>} : memref<16xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0], %cst {in_bounds = [true, true], permutation_map = affine_map<(d0) -> (d0, 0)>} : memref<16xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// CHECK-LABEL: func @matmul_transposed_broadcasted_2d
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}] {leadDimension = 0 : index, transpose} : memref<32x32xf16> -> !gpu.mma_matrix<16x16xf16, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}] {leadDimension = 0 : index} : memref<32x32xf16> -> !gpu.mma_matrix<16x16xf16, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xf16> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xf16, "AOp">, !gpu.mma_matrix<16x16xf16, "BOp"> -> !gpu.mma_matrix<16x16xf16, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xf16, "COp">, memref<16x16xf16>
func.func @matmul_transposed_broadcasted_2d(%arg0: memref<32x32xf16>, %arg1: memref<32x32xf16>, %arg2: memref<16x16xf16>) {
  %cst_0 = arith.constant dense<0.000000e+00> : vector<16x16xf16>
  %c0 = arith.constant 0 : index
  %cst = arith.constant 0.000000e+00 : f16
  %A = vector.transfer_read %arg0[%c0, %c0], %cst {in_bounds = [true, true], permutation_map = affine_map<(d0, d1) -> (d1, 0)>} : memref<32x32xf16>, vector<16x16xf16>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst {in_bounds = [true, true], permutation_map = affine_map<(d0, d1) -> (d1, 0)>} : memref<32x32xf16>, vector<16x16xf16>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst {in_bounds = [true, true]} : memref<16x16xf16>, vector<16x16xf16>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xf16>, vector<16x16xf16> into vector<16x16xf16>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xf16>, memref<16x16xf16>
  return
}

// Do not convert to subgroup_mma ops with integer types if signedness cannot be inferred.
// CHECK-LABEL: func @matmul_no_extend_int8
//   CHECK-DAG:   %[[A:.+]] = vector.transfer_read %{{.*}}[%{{.*}}, %{{.*}}], %{{.*}} {in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
//   CHECK-DAG:   %[[B:.+]] = vector.transfer_read %{{.*}}[%{{.*}}, %{{.*}}], %{{.*}} {in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
//   CHECK-DAG:   %[[C:.+]] = vector.transfer_read %{{.*}}[%{{.*}}, %{{.*}}], %{{.*}} {in_bounds = [true, true]} : memref<16x16xi32>, vector<16x16xi32>
//       CHECK:   %[[D:.+]] = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %[[A]], %[[B]], %[[C]] : vector<16x16xi8>, vector<16x16xi8> into vector<16x16xi32>
//       CHECK:   vector.transfer_write %{{.*}}, %{{.*}}[%{{.*}}, %{{.*}}] {in_bounds = [true, true]} : vector<16x16xi32>, memref<16x16xi32>
func.func @matmul_no_extend_int8(%arg0: memref<16x16xi8>, %arg1: memref<16x16xi8>, %arg2: memref<16x16xi32>) {
  %cst_0 = arith.constant dense<0> : vector<16x16xi8>
  %c0 = arith.constant 0 : index
  %cst_i8 = arith.constant 0 : i8
  %cst_i32 = arith.constant 0 : i32
  %A = vector.transfer_read %arg0[%c0, %c0], %cst_i8 {in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
  %B = vector.transfer_read %arg1[%c0, %c0], %cst_i8 {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst_i32 {in_bounds = [true, true]} : memref<16x16xi32>, vector<16x16xi32>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %A, %B, %C : vector<16x16xi8>, vector<16x16xi8> into vector<16x16xi32>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xi32>, memref<16x16xi32>
  return
}

// CHECK-LABEL: func @matmul_int8
//   CHECK-DAG:   %[[A:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xi8> -> !gpu.mma_matrix<16x16xsi8, "AOp">
//   CHECK-DAG:   %[[B:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xi8> -> !gpu.mma_matrix<16x16xsi8, "BOp">
//   CHECK-DAG:   %[[C:.+]] = gpu.subgroup_mma_load_matrix %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : memref<16x16xi32> -> !gpu.mma_matrix<16x16xi32, "COp">
//       CHECK:   %[[D:.+]] = gpu.subgroup_mma_compute %[[A]], %[[B]], %[[C]] : !gpu.mma_matrix<16x16xsi8, "AOp">, !gpu.mma_matrix<16x16xsi8, "BOp"> -> !gpu.mma_matrix<16x16xi32, "COp">
//       CHECK:   gpu.subgroup_mma_store_matrix %[[D]], %{{.*}}[%{{.*}}, %{{.*}}] {leadDimension = 16 : index} : !gpu.mma_matrix<16x16xi32, "COp">, memref<16x16xi32>
func.func @matmul_int8(%arg0: memref<16x16xi8>, %arg1: memref<16x16xi8>, %arg2: memref<16x16xi32>) {
  %cst_0 = arith.constant dense<0> : vector<16x16xi8>
  %c0 = arith.constant 0 : index
  %cst_i8 = arith.constant 0 : i8
  %cst_i32 = arith.constant 0 : i32
  %Ar = vector.transfer_read %arg0[%c0, %c0], %cst_i8 {in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
  %Br = vector.transfer_read %arg1[%c0, %c0], %cst_i8 {permutation_map = #map0, in_bounds = [true, true]} : memref<16x16xi8>, vector<16x16xi8>
  %C = vector.transfer_read %arg2[%c0, %c0], %cst_i32 {in_bounds = [true, true]} : memref<16x16xi32>, vector<16x16xi32>
  %Ae = arith.extsi %Ar : vector<16x16xi8> to vector<16x16xi32>
  %Be = arith.extsi %Br : vector<16x16xi8> to vector<16x16xi32>
  %D = vector.contract {indexing_maps = [#map1, #map2, #map3], iterator_types = ["parallel", "parallel", "reduction"], kind = #vector.kind<add>} %Ae, %Be, %C : vector<16x16xi32>, vector<16x16xi32> into vector<16x16xi32>
  vector.transfer_write %D, %arg2[%c0, %c0] {in_bounds = [true, true]} : vector<16x16xi32>, memref<16x16xi32>
  return
}
