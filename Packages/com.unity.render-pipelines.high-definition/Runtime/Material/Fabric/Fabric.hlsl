//-----------------------------------------------------------------------------
// SurfaceData and BSDFData
//-----------------------------------------------------------------------------
// SurfaceData is defined in Fabric.cs which generates Fabric.cs.hlsl
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Fabric/Fabric.cs.hlsl"
// Those define allow to include desired SSS/Transmission functions
#define MATERIAL_INCLUDE_SUBSURFACESCATTERING
#define MATERIAL_INCLUDE_TRANSMISSION
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/SubsurfaceScattering/SubsurfaceScattering.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"

//-----------------------------------------------------------------------------
// Texture and constant buffer declaration
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/LTCAreaLight/LTCAreaLight.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedFGD/PreIntegratedFGD.hlsl"

// #define FABRIC_DISPLAY_REFERENCE_IBL

//-----------------------------------------------------------------------------
// Helper functions/variable specific to this material
//-----------------------------------------------------------------------------

float4 GetDiffuseOrDefaultColor(BSDFData bsdfData, float replace)
{
    return float4(bsdfData.diffuseColor, 0.0);
}

float3 GetNormalForShadowBias(BSDFData bsdfData)
{
    return bsdfData.geomNormalWS;
}

float GetAmbientOcclusionForMicroShadowing(BSDFData bsdfData)
{
    return bsdfData.ambientOcclusion;
}

// Assume bsdfData.normalWS is init
void FillMaterialAnisotropy(float anisotropy, float3 tangentWS, float3 bitangentWS, inout BSDFData bsdfData)
{
    bsdfData.anisotropy = anisotropy;
    bsdfData.tangentWS = tangentWS;
    bsdfData.bitangentWS = bitangentWS;
}

// This function is use to help with debugging and must be implemented by any lit material
// Implementer must take into account what are the current override component and
// adjust SurfaceData properties accordingdly
void ApplyDebugToSurfaceData(float3x3 tangentToWorld, inout SurfaceData surfaceData)
{
#ifdef DEBUG_DISPLAY
    // NOTE: THe _Debug* uniforms come from /HDRP/Debug/DebugDisplay.hlsl

    // Override value if requested by user
    // this can be use also in case of debug lighting mode like diffuse only
    bool overrideAlbedo = _DebugLightingAlbedo.x != 0.0;
    bool overrideSmoothness = _DebugLightingSmoothness.x != 0.0;
    bool overrideNormal = _DebugLightingNormal.x != 0.0;
    bool overrideAO = _DebugLightingAmbientOcclusion.x != 0.0;

    if (overrideAlbedo)
    {
        float3 overrideAlbedoValue = _DebugLightingAlbedo.yzw;
        surfaceData.baseColor = overrideAlbedoValue;
    }

    if (overrideSmoothness)
    {
        float overrideSmoothnessValue = _DebugLightingSmoothness.y;
        surfaceData.perceptualSmoothness = overrideSmoothnessValue;
    }

    if (overrideNormal)
    {
        surfaceData.normalWS = tangentToWorld[2];
    }

    if (overrideAO)
    {
        float overrideAOValue = _DebugLightingAmbientOcclusion.y;
        surfaceData.ambientOcclusion = overrideAOValue;
    }

    if (_DebugFullScreenMode == FULLSCREENDEBUGMODE_VALIDATE_DIFFUSE_COLOR)
    {
        surfaceData.baseColor = pbrDiffuseColorValidate(surfaceData.baseColor, surfaceData.specularColor, false, false).xyz;
    }
    else if (_DebugFullScreenMode == FULLSCREENDEBUGMODE_VALIDATE_SPECULAR_COLOR)
    {
        surfaceData.baseColor = pbrSpecularColorValidate(surfaceData.baseColor, surfaceData.specularColor, false, false).xyz;
    }
#endif
}

// This function is similar to ApplyDebugToSurfaceData but for BSDFData
// Note: This will be available and used in ShaderPassForward.hlsl since in Fabric.shader,
// just before including the core code of the pass (ShaderPassForward.hlsl) we include
// Material.hlsl (or Lighting.hlsl which includes it) which in turn includes us,
// Fabric.shader, via the #if defined(UNITY_MATERIAL_*) glue mechanism.
void ApplyDebugToBSDFData(inout BSDFData bsdfData)
{
#ifdef DEBUG_DISPLAY
    // Override value if requested by user
    // this can be use also in case of debug lighting mode like specular only
    bool overrideSpecularColor = _DebugLightingSpecularColor.x != 0.0;

    if (overrideSpecularColor)
    {
        float3 overrideSpecularColor = _DebugLightingSpecularColor.yzw;
        bsdfData.fresnel0 = overrideSpecularColor;
    }
#endif
}

NormalData ConvertSurfaceDataToNormalData(SurfaceData surfaceData)
{
    NormalData normalData;
    normalData.normalWS = surfaceData.normalWS;
    normalData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);
    return normalData;
}

SSSData ConvertSurfaceDataToSSSData(SurfaceData surfaceData)
{
    SSSData sssData;

    sssData.diffuseColor = surfaceData.baseColor;
    sssData.subsurfaceMask = surfaceData.subsurfaceMask;
    sssData.diffusionProfileIndex = FindDiffusionProfileIndex(surfaceData.diffusionProfileHash);

    return sssData;
}

//-----------------------------------------------------------------------------
// conversion function for forward
//-----------------------------------------------------------------------------

BSDFData ConvertSurfaceDataToBSDFData(uint2 positionSS, SurfaceData surfaceData)
{
    BSDFData bsdfData;
    ZERO_INITIALIZE(BSDFData, bsdfData);

    // IMPORTANT: All enable flags are statically know at compile time, so the compiler can do compile time optimization
    bsdfData.materialFeatures = surfaceData.materialFeatures;

    bsdfData.diffuseColor = surfaceData.baseColor;
    bsdfData.specularOcclusion = surfaceData.specularOcclusion;
    bsdfData.normalWS = surfaceData.normalWS;
    bsdfData.geomNormalWS = surfaceData.geomNormalWS;
    bsdfData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);

    bsdfData.ambientOcclusion = surfaceData.ambientOcclusion;

    // Note: we have ZERO_INITIALIZE the struct so bsdfData.anisotropy == 0.0
    // Note: DIFFUSION_PROFILE_NEUTRAL_ID is 0

    // In forward everything is statically know and we could theorically cumulate all the material features. So the code reflect it.
    // However in practice we keep parity between deferred and forward, so we should constrain the various features.
    // The UI is in charge of setuping the constrain, not the code. So if users is forward only and want unleash power, it is easy to unleash by some UI change

    bsdfData.diffusionProfileIndex = FindDiffusionProfileIndex(surfaceData.diffusionProfileHash);

    if (HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_SUBSURFACE_SCATTERING))
    {
        // Assign profile id and overwrite fresnel0
        FillMaterialSSS(bsdfData.diffusionProfileIndex, surfaceData.subsurfaceMask, bsdfData);
    }

    if (HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION))
    {
        // Assign profile id and overwrite fresnel0
        FillMaterialTransmission(bsdfData.diffusionProfileIndex, surfaceData.thickness, surfaceData.transmissionMask, bsdfData);
    }

    if (!HasFlag(surfaceData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        FillMaterialAnisotropy(surfaceData.anisotropy, surfaceData.tangentWS, cross(surfaceData.normalWS, surfaceData.tangentWS), bsdfData);
    }

    // After the fill material SSS data has operated, in the case of the fabric we force the value of the fresnel0 term
    bsdfData.fresnel0 = surfaceData.specularColor;

    // roughnessT and roughnessB are clamped, and are meant to be used with punctual and directional lights.
    // perceptualRoughness is not clamped, and is meant to be used for IBL.
    // perceptualRoughness can be modify by FillMaterialClearCoatData, so ConvertAnisotropyToClampRoughness must be call after
    ConvertAnisotropyToClampRoughness(bsdfData.perceptualRoughness, bsdfData.anisotropy, bsdfData.roughnessT, bsdfData.roughnessB);

    ApplyDebugToBSDFData(bsdfData);

    return bsdfData;
}

//-----------------------------------------------------------------------------
// Debug method (use to display values)
//-----------------------------------------------------------------------------

// This function call the generated debug function and allow to override the debug output if needed
void GetSurfaceDataDebug(uint paramId, SurfaceData surfaceData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedSurfaceDataDebug(paramId, surfaceData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_FABRIC_SURFACEDATA_NORMAL_VIEW_SPACE:
        // Convert to view space
        {
            float3 vsNormal = TransformWorldToViewDir(surfaceData.normalWS);
            result = IsNormalized(vsNormal) ?  vsNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_FABRIC_SURFACEDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
        {
            float3 vsGeomNormal = TransformWorldToViewDir(surfaceData.geomNormalWS);
            result = IsNormalized(vsGeomNormal) ?  vsGeomNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    }
}

// This function call the generated debug function and allow to override the debug output if needed
void GetBSDFDataDebug(uint paramId, BSDFData bsdfData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedBSDFDataDebug(paramId, bsdfData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_FABRIC_BSDFDATA_NORMAL_VIEW_SPACE:
        // Convert to view space
        {
            float3 vsNormal = TransformWorldToViewDir(bsdfData.normalWS);
            result = IsNormalized(vsNormal) ?  vsNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    case DEBUGVIEW_FABRIC_BSDFDATA_GEOMETRIC_NORMAL_VIEW_SPACE:
        {
            float3 vsGeomNormal = TransformWorldToViewDir(bsdfData.geomNormalWS);
            result = IsNormalized(vsGeomNormal) ?  vsGeomNormal * 0.5 + 0.5 : float3(1.0, 0.0, 0.0);
            break;
        }
    }
}

void GetPBRValidatorDebug(SurfaceData surfaceData, inout float3 result)
{
    result = surfaceData.baseColor;
}

//-----------------------------------------------------------------------------
// PreLightData
//
// Make sure we respect naming conventions to reuse ShaderPassForward as is,
// ie struct (even if opaque to the ShaderPassForward) name is PreLightData,
// GetPreLightData prototype.
//-----------------------------------------------------------------------------

// Precomputed lighting data to send to the various lighting functions
struct PreLightData
{
    float NdotV;        // Could be negative due to normal mapping, use ClampNdotV()
    float partLambdaV;

    // IBL
    float3 iblR;                     // Reflected specular direction, used for IBL in EvaluateBSDF_Env()
    float  iblPerceptualRoughness;

    // Area lights (17 VGPRs)
    // TODO: 'orthoBasisViewNormal' is just a rotation around the normal and should thus be just 1x VGPR.
    float3x3 orthoBasisViewNormal;   // Right-handed view-dependent orthogonal basis around the normal (6x VGPRs)
    float3x3 ltcTransformDiffuse;    // Inverse transformation for Lambertian or Disney Diffuse        (4x VGPRs)
    float3x3 ltcTransformSpecular;   // Inverse transformation for GGX                                 (4x VGPRs)

    float3 specularFGD;              // Store preintegrated BSDF for both specular and diffuse
    float  diffuseFGD;
};

//
// ClampRoughness helper specific to this material
//
void ClampRoughness(inout PreLightData preLightData, inout BSDFData bsdfData, float minRoughness)
{
    bsdfData.roughnessT = max(minRoughness, bsdfData.roughnessT);
    bsdfData.roughnessB = max(minRoughness, bsdfData.roughnessB);
}

// This function is call to precompute heavy calculation before lightloop
PreLightData GetPreLightData(float3 V, PositionInputs posInput, inout BSDFData bsdfData)
{
    PreLightData preLightData;
    // Don't init to zero to allow to track warning about uninitialized data

    float3 N = bsdfData.normalWS;
    preLightData.NdotV = dot(N, V);
    preLightData.iblPerceptualRoughness = bsdfData.perceptualRoughness;

    float clampedNdotV = ClampNdotV(preLightData.NdotV);

    float unused;
    float3 iblN;

    // Reminder: This is a static if resolve at compile time
    if (!HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        GetPreIntegratedFGDGGXAndDisneyDiffuse(clampedNdotV, preLightData.iblPerceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, unused);

        float TdotV = dot(bsdfData.tangentWS, V);
        float BdotV = dot(bsdfData.bitangentWS, V);

        preLightData.partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, clampedNdotV, bsdfData.roughnessT, bsdfData.roughnessB);

        // perceptualRoughness is use as input and output here
        GetGGXAnisotropicModifiedNormalAndRoughness(bsdfData.bitangentWS, bsdfData.tangentWS, N, V, bsdfData.anisotropy, preLightData.iblPerceptualRoughness, iblN, preLightData.iblPerceptualRoughness);
    }
    else
    {
        preLightData.partLambdaV = 0.0;
        iblN = N;

        GetPreIntegratedFGDCharlieAndFabricLambert(clampedNdotV, preLightData.iblPerceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, unused);
    }

    preLightData.iblR = reflect(-V, iblN);

    // Area light
    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        // TODO USE THE FABRIC DIFFUSE FOR COTTON WOOL AND DISNEY DIFFUSE FOR the SILK
        preLightData.ltcTransformDiffuse  = k_identity3x3;
        preLightData.ltcTransformSpecular = SampleLtcMatrix(bsdfData.perceptualRoughness, clampedNdotV, LTCLIGHTINGMODEL_CHARLIE);
    }
    else
    {
        // TODO USE THE FABRIC DIFFUSE FOR COTTON WOOL AND DISNEY DIFFUSE FOR the SILK
        preLightData.ltcTransformDiffuse  = SampleLtcMatrix(bsdfData.perceptualRoughness, clampedNdotV, LTCLIGHTINGMODEL_DISNEY_DIFFUSE);
        preLightData.ltcTransformSpecular = SampleLtcMatrix(bsdfData.perceptualRoughness, clampedNdotV, LTCLIGHTINGMODEL_GGX);
    }

    // Construct a right-handed view-dependent orthogonal basis around the normal
    preLightData.orthoBasisViewNormal = GetOrthoBasisViewNormal(V, N, preLightData.NdotV);

    return preLightData;
}

//-----------------------------------------------------------------------------
// bake lighting function
//-----------------------------------------------------------------------------

// This define allow to say that we implement a ModifyBakedDiffuseLighting function to be call in PostInitBuiltinData
#define MODIFY_BAKED_DIFFUSE_LIGHTING

void ModifyBakedDiffuseLighting(float3 V, PositionInputs posInput, PreLightData preLightData, BSDFData bsdfData, inout BuiltinData builtinData)
{
    // Add GI transmission contribution to bakeDiffuseLighting, we then drop backBakeDiffuseLighting (i.e it is not used anymore, this save VGPR)
    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION))
    {
        builtinData.bakeDiffuseLighting += builtinData.backBakeDiffuseLighting * bsdfData.transmittance;
    }

    // For SSS we need to take into account the state of diffuseColor
    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_SUBSURFACE_SCATTERING))
    {
        bsdfData.diffuseColor = GetModifiedDiffuseColorForSSS(bsdfData);
    }

    // Premultiply (back) bake diffuse lighting information with diffuse pre-integration
    builtinData.bakeDiffuseLighting *= preLightData.diffuseFGD * bsdfData.diffuseColor;
}

//-----------------------------------------------------------------------------
// light transport functions
//-----------------------------------------------------------------------------

LightTransportData GetLightTransportData(SurfaceData surfaceData, BuiltinData builtinData, BSDFData bsdfData)
{
    LightTransportData lightTransportData;

    // DiffuseColor for lightmapping
    lightTransportData.diffuseColor = bsdfData.diffuseColor;
    lightTransportData.emissiveColor = builtinData.emissiveColor;

    return lightTransportData;
}

//-----------------------------------------------------------------------------
// LightLoop related function (Only include if required)
// HAS_LIGHTLOOP is define in Lighting.hlsl
//-----------------------------------------------------------------------------

#ifdef HAS_LIGHTLOOP

//-----------------------------------------------------------------------------
// BSDF share between directional light, punctual light and area light (reference)
//-----------------------------------------------------------------------------

bool IsNonZeroBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    float NdotL = dot(bsdfData.normalWS, L);

    return HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION) || (NdotL > 0.0);
}

// Ref: https://www.slideshare.net/jalnaga/custom-fabric-shader-for-unreal-engine-4
// For Fabric we have two type of BRDF
// Non-Metal: Cotton, deim, flax and common fabrics
// Cotton: Roughness of 1.0 (unless wet) - Fuzz rim - specular color is white but is looked like desaturated.
// Metal: Silk, satin, velvet, nylon and polyester
// Silk: Roughness 0.3 - 0.7 - anisotropic - varying specular color

// This function apply BSDF. Assumes that NdotL is positive.
CBSDF EvaluateBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    CBSDF cbsdf;
    ZERO_INITIALIZE(CBSDF, cbsdf);

    float3 N = bsdfData.normalWS;

    float NdotV = preLightData.NdotV;
    float NdotL = dot(N, L);
    float clampedNdotV = ClampNdotV(NdotV);
    float clampedNdotL = saturate(NdotL);
    float flippedNdotL = ComputeWrappedDiffuseLighting(-NdotL, TRANSMISSION_WRAP_LIGHT);

    float LdotV, NdotH, LdotH, invLenLV;
    GetBSDFAngle(V, L, NdotL, NdotV, LdotV, NdotH, LdotH, invLenLV);

    float  diffTerm;
    float3 specTerm;

    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        float D = D_Charlie(NdotH, bsdfData.roughnessT);
        // V_Charlie is expensive, use approx with V_Ashikhmin instead
        // float Vis = V_Charlie(NdotL, clampedNdotV, bsdfData.roughness);
        float Vis = V_Ashikhmin(NdotL, clampedNdotV);

        // Fabric are dieletric but we simulate forward scattering effect with colored specular (fuzz tint term)
        // We don't use Fresnel term for CharlieD
        float3 F = bsdfData.fresnel0;

        specTerm = F * Vis * D;

        diffTerm = FabricLambert(bsdfData.roughnessT);
    }
    else // MATERIALFEATUREFLAGS_FABRIC_SILK
    {
        // For silk we just use a tinted anisotropy
        float3 H = (L + V) * invLenLV;

        // For anisotropy we must not saturate these values
        float TdotH = dot(bsdfData.tangentWS, H);
        float TdotL = dot(bsdfData.tangentWS, L);
        float BdotH = dot(bsdfData.bitangentWS, H);
        float BdotL = dot(bsdfData.bitangentWS, L);

        // TODO: Do comparison between this correct version and the one from isotropic and see if there is any visual difference
        // We use abs(NdotL) to handle the none case of double sided
        float DV = DV_SmithJointGGXAniso(   TdotH, BdotH, NdotH, clampedNdotV, TdotL, BdotL, abs(NdotL),
                                            bsdfData.roughnessT, bsdfData.roughnessB, preLightData.partLambdaV);

        // Fabric are dieletric but we simulate forward scattering effect with colored specular (fuzz tint term)
        float3 F = F_Schlick(bsdfData.fresnel0, LdotH);

        specTerm = F * DV;

        // Use abs NdotL to evaluate diffuse term also for transmission
        // TODO: See with Evgenii about the clampedNdotV here. This is what we use before the refactor
        // but now maybe we want to revisit it for transmission
        diffTerm = DisneyDiffuse(clampedNdotV, abs(NdotL), LdotV, bsdfData.perceptualRoughness);
    }

    // The compiler should optimize these. Can revisit later if necessary.
    cbsdf.diffR = diffTerm * clampedNdotL;
    cbsdf.diffT = diffTerm * flippedNdotL;

    // Probably worth branching here for perf reasons.
    // This branch will be optimized away if there's no transmission (as NdotL > 0 is tested in IsNonZeroBSDF())
    // And we hope the compile will move specTerm in the branch in case of transmission (TODO: verify as we fabric this may not be true as we already have branch above...)
    if (NdotL > 0)
    {
        cbsdf.specR = specTerm * clampedNdotL;
    }

    // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
    return cbsdf;
}

//-----------------------------------------------------------------------------
// Surface shading (all light types) below
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/SurfaceShading.hlsl"

//-----------------------------------------------------------------------------
// EvaluateBSDF_Directional
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Directional(LightLoopContext lightLoopContext,
                                        float3 V, PositionInputs posInput, PreLightData preLightData,
                                        DirectionalLightData lightData, BSDFData bsdfData,
                                        BuiltinData builtinData)
{
    return ShadeSurface_Directional(lightLoopContext, posInput, builtinData,
                                    preLightData, lightData, bsdfData, V);
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Fabric/FabricReference.hlsl"
//-----------------------------------------------------------------------------
// EvaluateBSDF_Punctual (supports spot, point and projector lights)
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Punctual(LightLoopContext lightLoopContext,
                                     float3 V, PositionInputs posInput,
                                     PreLightData preLightData, LightData lightData,
                                     BSDFData bsdfData, BuiltinData builtinData)
{
    return ShadeSurface_Punctual(lightLoopContext, posInput, builtinData,
                                 preLightData, lightData, bsdfData, V);
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Line
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Line(   LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, LightData lightData, BSDFData bsdfData, BuiltinData builtinData)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    float3 positionWS = posInput.positionWS;

    float3 unL = lightData.positionRWS - positionWS;

    // We define the ellipsoid s.t. r1 = (r + len / 2), r2 = r3 = r.
    // TODO: This could be precomputed.
    float range          = lightData.range;
    float halfLength     = 0.5 * lightData.size.x;
    float invAspectRatio = saturate(range / (range + halfLength));

    // Compute the light attenuation.
    float intensity = EllipsoidalDistanceAttenuation(unL, lightData.right, invAspectRatio,
                                                     lightData.rangeAttenuationScale,
                                                     lightData.rangeAttenuationBias);

    // Terminate if the shaded point is too far away.
    if (intensity > 0)
    {
        lightData.diffuseDimmer  *= intensity;
        lightData.specularDimmer *= intensity;

        float3 center = mul(preLightData.orthoBasisViewNormal, unL);
        float3 axis   = mul(preLightData.orthoBasisViewNormal, lightData.right);

        float ltcValue;

        // ----- 1. Evaluate the diffuse part -----

        ltcValue = I_ltc_line(transpose(preLightData.ltcTransformDiffuse), center, axis, halfLength);

        // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
        lighting.diffuse += ltcValue * lightData.diffuseDimmer;

        UNITY_BRANCH if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION))
        {
            // Flip the view vector and the normal. The bitangent stays the same.
            float3x3 flipMatrix = float3x3(-1,  0,  0,
                                            0,  1,  0,
                                            0,  0, -1);

            // Use the Lambertian approximation for performance reasons.
            // TODO: performing the evaluation twice is very inefficient!
            ltcValue = I_ltc_line(flipMatrix, center, axis, halfLength);

            // We use diffuse lighting for accumulation since it is going to be blurred during the SSS pass.
            // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
            lighting.diffuse += bsdfData.transmittance * (ltcValue * lightData.diffuseDimmer);
        }

        // ----- 2. Evaluate the specular part -----

        ltcValue = I_ltc_line(transpose(preLightData.ltcTransformSpecular), center, axis, halfLength);

        lighting.specular += ltcValue * lightData.specularDimmer;

        // We need to multiply by the magnitude of the integral of the BRDF
        // ref: http://advances.realtimerendering.com/s2016/s2016_ltc_fresnel.pdf
        lighting.diffuse  *= lightData.color * preLightData.diffuseFGD;
        lighting.specular *= lightData.color * preLightData.specularFGD;

        // ----- 3. Debug display -----

    #ifdef DEBUG_DISPLAY
        if (_DebugLightingMode == DEBUGLIGHTINGMODE_LUX_METER)
        {
            ltcValue = I_ltc_line(k_identity3x3, center, axis, halfLength);

            // Only lighting, not BSDF
            lighting.diffuse  = lightData.color * (ltcValue * lightData.diffuseDimmer);
            // Apply area light on lambert then multiply by PI to cancel Lambert
            lighting.diffuse *= PI;
        }
    #endif
    }

    return lighting;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Rect
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Rect(   LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, LightData lightData, BSDFData bsdfData, BuiltinData builtinData)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    float3 positionWS = posInput.positionWS;

#if SHADEROPTIONS_BARN_DOOR
    // Apply the barn door modification to the light data
    RectangularLightApplyBarnDoor(lightData, positionWS);
#endif

    float3 unL = lightData.positionRWS - positionWS;

    if (dot(lightData.forward, unL) < FLT_EPS)
    {
        // Rotate the light direction into the light space.
        float3x3 lightToWorld = float3x3(lightData.right, lightData.up, -lightData.forward);
        unL = mul(unL, transpose(lightToWorld));

        // TODO: This could be precomputed.
        float halfWidth  = lightData.size.x * 0.5;
        float halfHeight = lightData.size.y * 0.5;

        // Define the dimensions of the attenuation volume.
        // TODO: This could be precomputed.
        float  range      = lightData.range;
        float3 invHalfDim = rcp(float3(range + halfWidth,
                                    range + halfHeight,
                                    range));

        // Compute the light attenuation.
    #ifdef ELLIPSOIDAL_ATTENUATION
        // The attenuation volume is an axis-aligned ellipsoid s.t.
        // r1 = (r + w / 2), r2 = (r + h / 2), r3 = r.
        float intensity = EllipsoidalDistanceAttenuation(unL, invHalfDim,
                                                        lightData.rangeAttenuationScale,
                                                        lightData.rangeAttenuationBias);
    #else
        // The attenuation volume is an axis-aligned box s.t.
        // hX = (r + w / 2), hY = (r + h / 2), hZ = r.
        float intensity = BoxDistanceAttenuation(unL, invHalfDim,
                                                lightData.rangeAttenuationScale,
                                                lightData.rangeAttenuationBias);
    #endif

        // Terminate if the shaded point is too far away.
        if (intensity != 0.0)
        {
            lightData.diffuseDimmer  *= intensity;
            lightData.specularDimmer *= intensity;

            // Translate the light s.t. the shaded point is at the origin of the coordinate system.
            lightData.positionRWS -= positionWS;

            float4x3 lightVerts;

            // TODO: some of this could be precomputed.
            lightVerts[0] = lightData.positionRWS + lightData.right * -halfWidth + lightData.up * -halfHeight; // LL
            lightVerts[1] = lightData.positionRWS + lightData.right * -halfWidth + lightData.up *  halfHeight; // UL
            lightVerts[2] = lightData.positionRWS + lightData.right *  halfWidth + lightData.up *  halfHeight; // UR
            lightVerts[3] = lightData.positionRWS + lightData.right *  halfWidth + lightData.up * -halfHeight; // LR

            // Rotate the endpoints into the local coordinate system.
            lightVerts = mul(lightVerts, transpose(preLightData.orthoBasisViewNormal));

            float4 ltcValue;

            // ----- 1. Evaluate the diffuse part -----

            ltcValue = EvaluateLTC_Rect(mul(lightVerts, preLightData.ltcTransformDiffuse), 1.0f,
                                        lightData.cookieMode, lightData.cookieScaleOffset);

            // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
            lighting.diffuse += ltcValue.rgb * (ltcValue.a * lightData.diffuseDimmer);

            if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_TRANSMISSION))
            {
                // Flip the view vector and the normal. The bitangent stays the same.
                float3x3 flipMatrix = float3x3(-1,  0,  0,
                                                0,  1,  0,
                                                0,  0, -1);

                // Use the Lambertian approximation for performance reasons.
                // TODO: performing the evaluation twice is very inefficient!
                ltcValue = EvaluateLTC_Rect(mul(lightVerts, flipMatrix), 1.0f,
                                            lightData.cookieMode, lightData.cookieScaleOffset);

                // We use diffuse lighting for accumulation since it is going to be blurred during the SSS pass.
                // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
                lighting.diffuse += bsdfData.transmittance * (ltcValue.rgb * (ltcValue.a * lightData.diffuseDimmer));
            }

            // ----- 2. Evaluate the specular part -----

            ltcValue = EvaluateLTC_Rect(mul(lightVerts, preLightData.ltcTransformSpecular), bsdfData.perceptualRoughness,
                                        lightData.cookieMode, lightData.cookieScaleOffset);

            lighting.specular += ltcValue.rgb * (ltcValue.a * lightData.specularDimmer);

            // Raytracing shadow algorithm require to evaluate lighting without shadow, so it defined SKIP_RASTERIZED_AREA_SHADOWS
            // This is only present in Lit Material as it is the only one using the improved shadow algorithm.
        #ifndef SKIP_RASTERIZED_AREA_SHADOWS
            SHADOW_TYPE shadow = EvaluateShadow_RectArea(lightLoopContext, posInput, lightData, builtinData, bsdfData.normalWS, normalize(lightData.positionRWS), length(lightData.positionRWS));
            lightData.color.rgb *= ComputeShadowColor(shadow, lightData.shadowTint, lightData.penumbraTint);
        #endif

            // We need to multiply by the magnitude of the integral of the BRDF
            // ref: http://advances.realtimerendering.com/s2016/s2016_ltc_fresnel.pdf
            lighting.diffuse  *= lightData.color * preLightData.diffuseFGD;
            lighting.specular *= lightData.color * preLightData.specularFGD;

            // ----- 3. Debug display -----

        #ifdef DEBUG_DISPLAY
            if (_DebugLightingMode == DEBUGLIGHTINGMODE_LUX_METER)
            {
                ltcValue = EvaluateLTC_Rect(lightVerts, 1.0f,
                                            lightData.cookieMode, lightData.cookieScaleOffset);

                // Only lighting, not BSDF
                lighting.diffuse  = lightData.color * ltcValue.rgb * (ltcValue.a * lightData.diffuseDimmer);
                // Apply area light on Lambert then multiply by PI to cancel Lambert
                lighting.diffuse *= PI;
            }
        #endif
        }
    }
    return lighting;
}

DirectLighting EvaluateBSDF_Area(LightLoopContext lightLoopContext,
    float3 V, PositionInputs posInput,
    PreLightData preLightData, LightData lightData,
    BSDFData bsdfData, BuiltinData builtinData)
{
    if (lightData.lightType == GPULIGHTTYPE_TUBE)
    {
        return EvaluateBSDF_Line(lightLoopContext, V, posInput, preLightData, lightData, bsdfData, builtinData);
    }
    else
    {
        return EvaluateBSDF_Rect(lightLoopContext, V, posInput, preLightData, lightData, bsdfData, builtinData);
    }
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_SSLighting for screen space lighting
// ----------------------------------------------------------------------------

IndirectLighting EvaluateBSDF_ScreenSpaceReflection(PositionInputs posInput,
                                                    PreLightData   preLightData,
                                                    BSDFData       bsdfData,
                                                    inout float    reflectionHierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    // TODO: this texture is sparse (mostly black). Can we avoid reading every texel? How about using Hi-S?
    float4 ssrLighting = LOAD_TEXTURE2D_X(_SsrLightingTexture, posInput.positionSS);
    InversePreExposeSsrLighting(ssrLighting);

    // Apply the weight on the ssr contribution (if required)
    ApplyScreenSpaceReflectionWeight(ssrLighting);

    // TODO: we should multiply all indirect lighting by the FGD value only ONCE.
    lighting.specularReflected = ssrLighting.rgb * preLightData.specularFGD;
    reflectionHierarchyWeight = ssrLighting.a;

    return lighting;
}

IndirectLighting EvaluateBSDF_ScreenspaceRefraction(LightLoopContext lightLoopContext,
                                                    float3 V, PositionInputs posInput,
                                                    PreLightData preLightData, BSDFData bsdfData,
                                                    EnvLightData envLightData,
                                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    // TODO

    return lighting;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Env
// ----------------------------------------------------------------------------

// _preIntegratedFGD and _CubemapLD are unique for each BRDF
IndirectLighting EvaluateBSDF_Env(  LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, EnvLightData lightData, BSDFData bsdfData,
                                    int influenceShapeType, int GPUImageBasedLightingType,
                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFRACTION)
        return lighting;

    float3 envLighting;
    float3 positionWS = posInput.positionWS;
    float weight = 1.0;

#ifdef FABRIC_DISPLAY_REFERENCE_IBL
    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        envLighting = IntegrateSpecularCottonWoolIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData);
    }
    else
    {
        envLighting = IntegrateSpecularSilkIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData);
    }
#else
    float3 R = preLightData.iblR;

    // Note: using influenceShapeType and projectionShapeType instead of (lightData|proxyData).shapeType allow to make compiler optimization in case the type is know (like for sky)
    float intersectionDistance = EvaluateLight_EnvIntersection(positionWS, bsdfData.normalWS, lightData, influenceShapeType, R, weight);

    // If it is a silk, we need to use the GGX convolution (slice0), otherwise the charlie convolution (slice1)
    int sliceIndex = 0;
    if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_FABRIC_COTTON_WOOL))
    {
        sliceIndex = _EnvSliceSize - 1;
    }

    float4 preLD = SampleEnvWithDistanceBaseRoughness(lightLoopContext, posInput, lightData, R, preLightData.iblPerceptualRoughness, intersectionDistance, sliceIndex);
    weight *= preLD.a; // Used by planar reflection to discard pixel

    envLighting = preLightData.specularFGD * preLD.rgb;

#endif
    UpdateLightingHierarchyWeights(hierarchyWeight, weight);
    envLighting *= weight * lightData.multiplier;
    lighting.specularReflected = envLighting;

    return lighting;
}

//-----------------------------------------------------------------------------
// PostEvaluateBSDF
// ----------------------------------------------------------------------------

void PostEvaluateBSDF(  LightLoopContext lightLoopContext,
                        float3 V, PositionInputs posInput,
                        PreLightData preLightData, BSDFData bsdfData, BuiltinData builtinData, AggregateLighting lighting,
                        out LightLoopOutput lightLoopOutput)
{
    AmbientOcclusionFactor aoFactor;
    GetScreenSpaceAmbientOcclusionMultibounce(posInput.positionSS, preLightData.NdotV, bsdfData.perceptualRoughness, bsdfData.ambientOcclusion, bsdfData.specularOcclusion, bsdfData.diffuseColor, bsdfData.fresnel0, aoFactor);
    ApplyAmbientOcclusionFactor(aoFactor, builtinData, lighting);

    // Subsurface scattering mode
    float3 modifiedDiffuseColor = GetModifiedDiffuseColorForSSS(bsdfData);

    // Apply the albedo to the direct diffuse lighting (only once). The indirect (baked)
    // diffuse lighting has already multiply the albedo in ModifyBakedDiffuseLighting().
    lightLoopOutput.diffuseLighting = modifiedDiffuseColor * lighting.direct.diffuse + builtinData.bakeDiffuseLighting + builtinData.emissiveColor;
    lightLoopOutput.specularLighting = lighting.direct.specular + lighting.indirect.specularReflected;

    // TODO: Multiscattering for cloth?

#ifdef DEBUG_DISPLAY
    PostEvaluateBSDFDebugDisplay(aoFactor, builtinData, lighting, bsdfData.diffuseColor, lightLoopOutput);
#endif
}

#endif // #ifdef HAS_LIGHTLOOP
