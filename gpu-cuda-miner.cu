#include <cstdint>
#include <cuda_runtime.h>

#ifdef __INTELLISENSE__
#define __launch_bounds__(blocksize)
#endif

#if defined(_MSC_VER)
#define ALIGN(x) __declspec(align(x))
#else
#define ALIGN(x) __attribute__((aligned(x)))
#endif

#if __CUDA_ARCH__ >= 320
__device__ __forceinline__
uint64_t rotr64(const uint64_t value, const int offset)
{
	uint2 result;
	if(offset < 32)
	{
		asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(result.x) : "r"(__double2loint(__longlong_as_double(value))), "r"(__double2hiint(__longlong_as_double(value))), "r"(offset));
		asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(result.y) : "r"(__double2hiint(__longlong_as_double(value))), "r"(__double2loint(__longlong_as_double(value))), "r"(offset));
	}
	else
	{
		asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(result.x) : "r"(__double2hiint(__longlong_as_double(value))), "r"(__double2loint(__longlong_as_double(value))), "r"(offset));
		asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(result.y) : "r"(__double2loint(__longlong_as_double(value))), "r"(__double2hiint(__longlong_as_double(value))), "r"(offset));
	}
	return __double_as_longlong(__hiloint2double(result.y, result.x));
}
#else
__device__ __forceinline__
uint64_t rotr64(const uint64_t x, const int offset)
{
	uint64_t result;
	asm("{\n\t"
		".reg .b64 lhs;\n\t"
		".reg .u32 roff;\n\t"
		"shr.b64 lhs, %1, %2;\n\t"
		"sub.u32 roff, 64, %2;\n\t"
		"shl.b64 %0, %1, roff;\n\t"
		"add.u64 %0, %0, lhs;\n\t"
		"}\n"
		: "=l"(result) : "l"(x), "r"(offset));
	return result;
}
#endif

#define blocksize 256
#define npt 64

__global__ void __launch_bounds__(blocksize, 4) nonceGrind(const uint64_t *const __restrict__ headerIn, uint64_t *const __restrict__ hashOut, uint64_t *const __restrict__ nonceOut, const uint64_t *const __restrict__ v1)
{
	uint64_t header[10], h[4], v[16];
	int i;

	const uint32_t id = (blockDim.x * blockIdx.x + threadIdx.x)*npt;

#pragma unroll
	for(i = 0; i < 10; i++)
		header[i] = headerIn[i];

	for(i = 0; i < npt; i++)
	{
		((uint32_t*)header)[8] = id + i;
		v[2] = 0x3c6ef372fe94f82bu + 0x1f83d9abfb41bd6bu + header[4]; v[14] = rotr64(~0x1f83d9abfb41bd6bu ^ v[2], 32); v[10] = 0x3c6ef372fe94f82bu + v[14]; v[6] = rotr64(0x1f83d9abfb41bd6bu ^ v[10], 24);
		v[2] = v[2] + v[6] + header[5]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = 0xa54ff53a5f1d36f1u + 0x5be0cd19137e2179u + header[6]; v[15] = rotr64(0x5be0cd19137e2179u ^ v[3], 32); v[11] = 0xa54ff53a5f1d36f1u + v[15]; v[7] = rotr64(0x5be0cd19137e2179u ^ v[11], 24);
		v[3] = v[3] + v[7] + header[7]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v1[0] + v1[5] + header[8]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v1[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[9]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v1[1] + v[6];            v[12] = rotr64(v1[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7];             v[13] = rotr64(v1[13] ^ v[2], 32); v[8] = v1[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v1[4];            v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v1[9] + v[14]; v[4] = rotr64(v1[4] ^ v[9], 24);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[4]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[8]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[9]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[6]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[1]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[0]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[2]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[7]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[5]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[3]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[8]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5];             v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[0]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[5]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[2]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[3]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[6]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[7]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[1]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[9]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[4]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4] + header[7]; v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[9]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[3]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[1]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[2]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[6]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[5]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[4]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[0]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[8]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4] + header[9]; v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[0]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[5]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[7]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[2]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[4]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[1]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[6]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[8]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[3]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4] + header[2]; v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[6]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5];             v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[0]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[8]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[3]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[4]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[7]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[5]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[1]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[9]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[5]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[1]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5];             v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[4]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[0]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[7]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[6]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[3]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[9]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[2]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[8]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4];            v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[7]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5];             v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[1]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[3]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[9]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[5]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[0]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[4]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[8]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[6]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4] + header[2]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4] + header[6]; v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5];             v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[9]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[3]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[0]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[8]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[2]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[7]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[1]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[4]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[5]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[2]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[8]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[4]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[7]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[6]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[1]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[5]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6] + header[9]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7] + header[3]; v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[0]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4] + header[0]; v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4] + header[1]; v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[2]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[3]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[4]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6] + header[5]; v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7] + header[6]; v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[7]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[8]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5] + header[9]; v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 63);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6];             v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 63);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 63);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4];             v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 63);

		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 32); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 24);
		v[0] = v[0] + v[4];             v[12] = rotr64(v[12] ^ v[0], 16); v[8] = v[8] + v[12]; v[4] = rotr64(v[4] ^ v[8], 63);
		v[1] = v[1] + v[5] + header[4]; v[13] = rotr64(v[13] ^ v[1], 32); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 24);
		v[1] = v[1] + v[5] + header[8]; v[13] = rotr64(v[13] ^ v[1], 16); v[9] = v[9] + v[13]; v[5] = rotr64(v[5] ^ v[9], 63);
		v[2] = v[2] + v[6] + header[9]; v[14] = rotr64(v[14] ^ v[2], 32); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 24);
		v[2] = v[2] + v[6];             v[14] = rotr64(v[14] ^ v[2], 16); v[10] = v[10] + v[14]; v[6] = rotr64(v[6] ^ v[10], 63);
		v[3] = v[3] + v[7];             v[15] = rotr64(v[15] ^ v[3], 32); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 24);
		v[3] = v[3] + v[7] + header[6]; v[15] = rotr64(v[15] ^ v[3], 16); v[11] = v[11] + v[15]; v[7] = rotr64(v[7] ^ v[11], 63);
		v[0] = v[0] + v[5] + header[1]; v[15] = rotr64(v[15] ^ v[0], 32); v[10] = v[10] + v[15]; v[5] = rotr64(v[5] ^ v[10], 24);
		v[0] = v[0] + v[5];             v[15] = rotr64(v[15] ^ v[0], 16); v[10] = v[10] + v[15];
		v[1] = v[1] + v[6] + header[0]; v[12] = rotr64(v[12] ^ v[1], 32); v[11] = v[11] + v[12]; v[6] = rotr64(v[6] ^ v[11], 24);
		v[1] = v[1] + v[6] + header[2]; v[12] = rotr64(v[12] ^ v[1], 16); v[11] = v[11] + v[12];
		v[2] = v[2] + v[7];             v[13] = rotr64(v[13] ^ v[2], 32); v[8] = v[8] + v[13]; v[7] = rotr64(v[7] ^ v[8], 24);
		v[2] = v[2] + v[7] + header[7]; v[13] = rotr64(v[13] ^ v[2], 16); v[8] = v[8] + v[13];
		v[3] = v[3] + v[4] + header[5]; v[14] = rotr64(v[14] ^ v[3], 32); v[9] = v[9] + v[14]; v[4] = rotr64(v[4] ^ v[9], 24);
		v[3] = v[3] + v[4] + header[3]; v[14] = rotr64(v[14] ^ v[3], 16); v[9] = v[9] + v[14];

		h[0] = 0x6A09E667F2BDC928 ^ v[0] ^ v[8];
		h[1] = 0xbb67ae8584caa73b ^ v[1] ^ v[9];
		h[2] = 0x3c6ef372fe94f82b ^ v[2] ^ v[10];
		h[3] = 0xa54ff53a5f1d36f1 ^ v[3] ^ v[11];
		if(*((uint32_t*)h) == 0)
		{
			*nonceOut = header[4];
#pragma unroll
			for(i = 0; i < 4; i++)
				hashOut[i] = h[i];
			return;
		}
	}
}

void nonceGrindcuda(cudaStream_t cudastream, uint32_t threads, uint64_t *blockHeader, uint64_t *headerHash, uint64_t *nonceOut, uint64_t *vpre)
{
	nonceGrind <<<threads / blocksize / npt, blocksize, 0, cudastream >>>(blockHeader, headerHash, nonceOut, vpre);
}


