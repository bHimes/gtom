#include "../Prerequisites.cuh"
#include "../Functions.cuh"
#include "../glm/glm.hpp"
#include "../glm/gtc/matrix_transform.hpp"
#include "../glm/gtx/quaternion.hpp"
#include "../glm/gtx/euler_angles.hpp"

texture<tfloat, 2> texBackprojImage;


////////////////////////////
//CUDA kernel declarations//
////////////////////////////

__global__ void ProjBackwardKernel(tfloat* d_volume, int3 dimsvolume, int3 dimsimage, glm::mat4 rotation, float weight);


/////////////////////////////////////////////
//Equivalent of TOM's tom_backproj3d method//
/////////////////////////////////////////////

void d_ProjBackward(tfloat* d_volume, int3 dimsvolume, tfloat* d_image, int3 dimsimage, tfloat2* angles, tfloat* weight, int batch)
{
	cudaChannelFormatDesc descInput = cudaCreateChannelDesc<tfloat>();
	texBackprojImage.normalized = false;
	texBackprojImage.filterMode = cudaFilterModeLinear;
	texBackprojImage.addressMode[0] = cudaAddressModeBorder;
	texBackprojImage.addressMode[1] = cudaAddressModeBorder;

	size_t TpB = min(192, NextMultipleOf(dimsvolume.x, 32));
	dim3 grid = dim3((dimsvolume.x + TpB - 1) / TpB, dimsvolume.y, dimsvolume.z);
	for (int b = 0; b < batch; b++)
	{
		cudaBindTexture2D(0,
						  texBackprojImage, 
						  d_image + Elements(dimsimage) * b, 
						  descInput, 
						  dimsimage.x, 
						  dimsimage.y, 
						  dimsimage.x * sizeof(tfloat));

		glm::mat4 rotationPhi = glm::eulerAngleZ(angles[b].x);
		glm::mat4 rotationTheta = glm::eulerAngleY(-angles[b].y);
		glm::mat4 rotationMat = rotationPhi * rotationTheta;
		ProjBackwardKernel <<<grid, TpB>>> (d_volume, dimsvolume, dimsimage, rotationMat, weight[b]);

		cudaUnbindTexture(texBackprojImage);
	}
}


////////////////
//CUDA kernels//
////////////////

__global__ void ProjBackwardKernel(tfloat* d_volume, int3 dimsvolume, int3 dimsimage, glm::mat4 rotation, float weight)
{
	int xvol = blockIdx.x * blockDim.x + threadIdx.x;
	if(xvol >= dimsvolume.x)
		return;

	glm::vec4 voxelpos = glm::vec4((tfloat)(xvol - dimsvolume.x / 2), 
								   (tfloat)((int)blockIdx.y - dimsvolume.y / 2), 
								   (tfloat)((int)blockIdx.z - dimsvolume.z / 2), 
								   1.0f);
	glm::vec4 rotated = voxelpos * rotation;

	rotated.x += (tfloat)(dimsimage.x / 2) + (tfloat)0.5;
	rotated.y += (tfloat)(dimsimage.y / 2) + (tfloat)0.5;
	d_volume[(blockIdx.z * dimsvolume.y + blockIdx.y) * dimsvolume.x + xvol] += weight * tex2D(texBackprojImage, 
																								rotated.x, 
																								rotated.y);
}