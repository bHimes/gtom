#include "Prerequisites.cuh"

#define GLM_FORCE_RADIANS
#define GLM_FORCE_INLINE
#define GLM_FORCE_CUDA
#include "glm/glm.hpp"

glm::mat4 Matrix4Euler(tfloat3 angles);
glm::mat4 Matrix4EulerLegacy(tfloat2 angles);
glm::mat3 Matrix3Euler(tfloat3 angles);

glm::mat4 Matrix4Translation(tfloat3 translation);
glm::mat4 Matrix4Scale(tfloat3 scale);
glm::mat4 Matrix4RotationX(tfloat angle);
glm::mat4 Matrix4RotationY(tfloat angle);
glm::mat4 Matrix4RotationZ(tfloat angle);

glm::mat3 Matrix3Scale(tfloat3 scale);
glm::mat3 Matrix3RotationX(tfloat angle);
glm::mat3 Matrix3RotationY(tfloat angle);
glm::mat3 Matrix3RotationZ(tfloat angle);

glm::mat3 Matrix3Translation(tfloat2 translation);
glm::mat2 Matrix2Scale(tfloat2 scale);
glm::mat2 Matrix2Rotation(tfloat angle);

tfloat3* GetEqualAngularSpacing(tfloat2 phirange, tfloat2 thetarange, tfloat2 psirange, tfloat increment, int &numangles);