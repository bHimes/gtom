#include "Prerequisites.cuh"
#include "Angles.cuh"
#include "CTF.cuh"
#include "CubicInterp.cuh"
#include "DeviceFunctions.cuh"
#include "FFT.cuh"
#include "Generics.cuh"
#include "Helper.cuh"
#include "ImageManipulation.cuh"
#include "Masking.cuh"
#include "Transformation.cuh"


namespace gtom
{
	//////////////////////////////////////////////////////
	//Calculate power spectrum based on multiple regions//
	//////////////////////////////////////////////////////

	void d_CTFPeriodogram(tfloat* d_image, int2 dimsimage, float overlapfraction, int2 dimsregion, int2 dimspadded, tfloat* d_output2d, bool dopost)
	{
		// Create uniform grid over the image
		int2 regions;
		int3* h_origins = GetEqualGridSpacing(dimsimage, dimsregion, overlapfraction, regions);
		int3* d_origins = (int3*)CudaMallocFromHostArray(h_origins, Elements2(regions) * sizeof(int3));
		free(h_origins);

		int norigins = Elements2(regions);

		tfloat* d_temp2d;
		cudaMalloc((void**)&d_temp2d, ElementsFFT2(dimspadded) * norigins * sizeof(tfloat));

		// Call the custom-grid version to extract 2D spectra
		d_CTFPeriodogram(d_image, dimsimage, d_origins, norigins, dimsregion, dimspadded, d_temp2d, dopost);

		d_ReduceMean(d_temp2d, d_output2d, ElementsFFT2(dimspadded), norigins);

		cudaFree(d_temp2d);
		cudaFree(d_origins);
	}

	void d_CTFPeriodogram(tfloat* d_image, int2 dimsimage, int3* d_origins, int norigins, int2 dimsregion, int2 dimspadded, tfloat* d_output2d, bool dopost, cufftHandle planforw)
	{
		cufftHandle ownplanforw = planforw;
		if (planforw == NULL)
			ownplanforw = d_FFTR2CGetPlan(2, toInt3(dimspadded), norigins);

		int memlimit = 128 << 20;
		int batchsize = norigins; // tmin(norigins, memlimit / (int)(Elements2(dimsregion) * 2 * sizeof(tfloat)));

		tfloat* d_extracted;
		cudaMalloc((void**)&d_extracted, norigins * Elements2(dimspadded) * sizeof(tfloat));
		tcomplex* d_extractedft;
		cudaMalloc((void**)&d_extractedft, norigins * ElementsFFT2(dimspadded) * sizeof(tcomplex));
				
		d_ExtractMany(d_image, d_extracted, toInt3(dimsimage), toInt3(dimsregion), d_origins, norigins);
		//d_WriteMRC(d_extracted, toInt3(dimsregion.x, dimsregion.y, curbatch), "d_extracted.mrc");

		d_NormMonolithic(d_extracted, d_extracted, Elements2(dimsregion), T_NORM_MEAN01STD, norigins);
		tfloat radius = dimsregion.x * 3 / 4.0f / 2;
		d_SphereMask(d_extracted, d_extracted, toInt3(dimsregion), &radius, dimsregion.x * 1 / 4.0f / 2, NULL, norigins);
		//d_HammingMask(d_extracted, d_extracted, toInt3(dimsregion), &radius, NULL, norigins);
		//d_HammingMaskBorderDistance(d_extracted, d_extracted, toInt3(dimsregion), dimsregion.x / 4, curbatch);
		if (dimsregion.x != dimspadded.x || dimsregion.y != dimspadded.y)
		{
			d_Pad(d_extracted, (tfloat*)d_extractedft, toInt3(dimsregion), toInt3(dimspadded), T_PAD_VALUE, (tfloat)0, norigins);
			//d_NormMonolithic((tfloat*)d_extractedft, d_extracted, Elements2(dimspadded), T_NORM_MEAN01STD, curbatch);
		}
		else
		{
			//d_NormMonolithic(d_extracted, d_extracted, Elements2(dimspadded), T_NORM_MEAN01STD, curbatch);
		}
		//d_WriteMRC(d_extracted, toInt3(dimspadded.x, dimspadded.y, norigins), "d_extracted.mrc");
		d_FFTR2C(d_extracted, d_extractedft, &ownplanforw);
		//d_WriteMRC(d_extracted, toInt3(dimspadded.x / 2 + 1, dimspadded.y, curbatch), "d_extractedft.mrc");

		if (dopost)
		{
			d_Abs(d_extractedft, d_extracted, norigins * ElementsFFT2(dimspadded));
			d_AddScalar(d_extracted, d_extracted, norigins * ElementsFFT2(dimspadded), (tfloat)1e-6);
			d_Log(d_extracted, d_extracted, norigins * ElementsFFT2(dimspadded));
			d_MultiplyByVector(d_extracted, d_extracted, d_extracted, ElementsFFT2(dimspadded) * norigins);
		}
		else
		{
			d_Abs(d_extractedft, d_output2d, norigins * ElementsFFT2(dimspadded));
		}

		//d_RemapHalfFFT2Half(d_extracted, d_output2d, toInt3(dimspadded), norigins);
		//d_WriteMRC(d_output2d, toInt3(dimspadded.x / 2 + 1, dimspadded.y, norigins), "d_extractedoutput.mrc");

		cudaFree(d_extractedft);
		cudaFree(d_extracted);

		if (planforw == NULL)
			cufftDestroy(ownplanforw);
	}
}