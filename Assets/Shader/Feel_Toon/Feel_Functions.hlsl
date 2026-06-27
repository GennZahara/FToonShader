#ifndef FEEL_FUNCTIONS_INCLUDED
#define FEEL_FUNCTIONS_INCLUDED

//  Feel_Functions.hlsl — 함수 모음
// Celshading, Rim Light, SSS, SDF계산등등.. 기능구현을 위한 계산함수들

//  1. CEL SHADING2

half GetShadowArea(half ndotL, half atten)
{
    half halfLambert = ndotL * 0.5h + 0.5h;
    return halfLambert * atten;
}


//  Ramp UV — Floor 양자화
//  celSteps 단계로 명암을 끊어 셀 경계 생성.

float2 GetRampUV_Floor(half shadowArea, half celSteps)
{
    half safeSteps = max(2.0h, celSteps);
    half u = floor(shadowArea * safeSteps) / (safeSteps - 1.0h);
    return float2(saturate(u), 0.5);
}


// Ramp UV — 직접 매핑 
//  shadowArea를 U 좌표로 그대로 사용. Ramp Texture가 경계를 정의.

float2 GetRampUV_Direct(half shadowArea)
{
    return float2(saturate(shadowArea), 0.5);
}


// Smoothstep shadowFactor 
//  Ramp 없는버전, Ramp 없이 부드러운 셀 경계 생성.
//  threshold ± smoothness → 총 전환 폭 = smoothness × 2.

half GetCelShadingSmooth(half shadowArea, half threshold, half smoothness)
{
    float minEdge = saturate((float)threshold - (float)smoothness);
    float maxEdge = saturate((float)threshold + (float)smoothness);
    return (half)smoothstep(minEdge, maxEdge, (float)shadowArea);
}


//  2. SDF FACE SHADOW
//  _USE_SDF_FACE OFF → 기본 NdotL (FaceFragment에서 분기)
//  _USE_SDF_FACE ON, _USE_SDF_TEX OFF → 구/원기둥 빛쏴주기 (코드 기반으로만, No Texture)
//  _USE_SDF_FACE ON, _USE_SDF_TEX ON  → SDF 텍스처 기반 (메시 UV 픽셀별 샘플링)


// 빛 방향 XZ 투영 
//  Y 성분 제거 후 재정규화. 빛이 완전 수직(Y≈1)일 때 zero-vector 방지.

half3 FlattenLightDir(half3 lightDir)
{
    half3 flat = half3(lightDir.x, 0.0h, lightDir.z);
    half  len  = length(flat);
    return len > 0.001h ? flat / len : half3(0.0h, 0.0h, 1.0h);
}


//  구/원기둥 프록시 경로 (ObjectToWorld 자동 추출)
//  얼굴 오브젝트 pivot을 구 중심으로 가정.
//  픽셀마다 구 표면 노멀 → half-lambert 값 반환 (smoothstep 전 raw area).
//  Fragment에서 1st/2nd Shadow threshold를 각각 적용.

half GetFaceShadowArea_Proxy(float3 positionWS, half3 lightDir, half shadowOffset)
{
    float3 faceCenter = float3(
        unity_ObjectToWorld._m03,
        unity_ObjectToWorld._m13,
        unity_ObjectToWorld._m23
    );

    half3 sphereNormal = normalize((half3)(positionWS - faceCenter));
    half  NdotL        = dot(sphereNormal, lightDir);
    return NdotL * 0.5h + 0.5h + shadowOffset;
}


// SDF Texture 경로 — raw 데이터 반환 (smoothstep 전)
//  sdfValue:       픽셀별 SDF 거리값 (텍스처 샘플링, 1회만 수행)
//  angleThreshold: 빛 각도 기반 threshold (0=정면, 1=후면)
//  Fragment에서 1st/2nd Shadow threshold를 각각 적용.
//  좌우 대칭: 오른쪽에서 빛이 올 때 UV.x 반전으로 미러링.

void GetFaceShadowData_SDF(half3 lightDir, float2 uv,
                           half shadowOffset, half useDual,
                           TEXTURE2D(sdfTex), SAMPLER(sampler_sdfTex),
                           out half sdfValue, out half angleThreshold)
{
    //  정면/우측 축 — 모델 임포트 회전에 견고하게 도출.
    //  (이 캐릭터는 메시가 X축 270° 회전 → object +Z가 world 위를 가리킴.
    //   object +Z를 그대로 쓰면 faceForward가 수직이 돼 LdotF가 항상 0이 되는 버그가 있었음.)
    //  업라이트 캐릭터 가정: object +X(우측)를 수평 투영 → world-up과 외적으로 정면 도출.
    half3 worldUp   = half3(0.0h, 1.0h, 0.0h);
    half3 faceRight = normalize(half3(
        unity_ObjectToWorld._m00,
        unity_ObjectToWorld._m10,
        unity_ObjectToWorld._m20
    ));
    faceRight = normalize(faceRight - worldUp * dot(faceRight, worldUp));   // 수평 투영
    half3 faceForward = normalize(cross(faceRight, worldUp));               // right × up = 정면

    half3 L     = FlattenLightDir(lightDir);
    half  LdotF = dot(L, faceForward);
    half  LdotR = dot(L, faceRight);

    half side = smoothstep(-0.02h, 0.02h, LdotR);   // 0=빛 왼쪽, 1=빛 오른쪽
    if (useDual > 0.5)
    {
        //  [R/G 듀얼맵] 좌/우 광원용 per-side SDF를 직접 선택 — UV 미러 불필요(중앙 seam 제거).
        //  R = 한쪽 광원, G = 반대쪽 광원. (B는 둘의 평균이라 미러가 필요)
        half sdfRch = SAMPLE_TEXTURE2D(sdfTex, sampler_sdfTex, uv).r;
        half sdfGch = SAMPLE_TEXTURE2D(sdfTex, sampler_sdfTex, uv).g;
        sdfValue    = lerp(sdfRch, sdfGch, side);
    }
    else
    {
        //  [B + 미러] B 채널 = 풀페이스 합본 SDF. 빛이 반대편이면 UV.x 반전으로 미러링.
        float2 uvR  = float2(1.0 - uv.x, uv.y);
        half   sdfL = SAMPLE_TEXTURE2D(sdfTex, sampler_sdfTex, uv).b;
        half   sdfR = SAMPLE_TEXTURE2D(sdfTex, sampler_sdfTex, uvR).b;
        sdfValue    = lerp(sdfL, sdfR, 1.0h - side);   // side와 반대(기존 동작 유지)
    }

    // 빛 각도 → threshold (선형 매핑, acos 제거로 ±180° 근처 정밀도 안정화)
    //   L·F=1 (정면) → 0 (fully lit), L·F=0 → 0.5, L·F=-1 (후면) → 1 (fully shadow)
    angleThreshold = saturate(0.5h - LdotF * 0.5h + shadowOffset);
}


//  3. STYLIZED SSS (Subsurface Scattering) — Rim 기반 (실루엣 fresnel + 역광 게이팅)
//  Rim Light과 같은 실루엣 가장자리에 SSS 색을 얹되, 빛이 뒤에 있을수록 강해짐(투과 느낌).
//    rim       = pow(1 - NdotV, power)        → RimLight과 동일한 fresnel 실루엣
//    backlight = saturate(VdotL_back + bias)  → 역광일수록 강함
//  프로퍼티 재매핑: gradientRange → 실루엣 날카로움(power), sssDistortion → 역광 바이어스, gradientStrength/sssScale → 세기

half3 GetSSS(half3 normalWS, half3 lightDirWS, half3 viewDirWS,
             half3 sssColor, half3 lightColor,
             half sssScale, half sssDistortion,
             half gradientRange, half gradientStrength)
{
    // [Rim 기반 SSS] Rim Light과 같은 실루엣(fresnel) 영역에 적용 + 역광일수록 강해지는 SSS 특성.
    half  power     = lerp(8.0h, 1.0h, saturate(gradientRange));   // 실루엣 가장자리 날카로움
    half  ndotv     = saturate(dot(normalWS, viewDirWS));
    half  rim       = pow(1.0h - ndotv, power);                    // RimLight과 동일한 fresnel 실루엣
    half  backlight = saturate(dot(viewDirWS, -lightDirWS) + sssDistortion);  // 역광일수록 강함 (distortion=바이어스)

    return rim * backlight * sssScale * gradientStrength * sssColor * lightColor;
}

//  4. MATCAP

// 뷰 공간 노멀의 xy → MatCap UV 로 샘플링.
// normalWS 는 호출 전에 normalize 완료 가정.
// N_full(노멀맵 있을 때) 또는 N_vertex(없을 때) 를 그대로 넘기면 됨.

half3 GetMatCap(TEXTURE2D_PARAM(matCapTex, sampler_matCapTex),
                half3 normalWS,
                half3 matCapColor, half matCapIntensity, half shadowFactor)
{
    // 월드 → 뷰 공간 (카메라 회전만 반영, 위치·스케일 제외)
    half3  normalVS  = normalize(mul((float3x3)UNITY_MATRIX_V, normalWS));
    float2 matCapUV  = float2(normalVS.x, normalVS.y) * 0.5 + 0.5;
    half3  capSample = SAMPLE_TEXTURE2D(matCapTex, sampler_matCapTex, matCapUV).rgb;

    // shadowFactor: 그림자 영역에서 MatCap 억제 (lit zone에서만 강하게)
    return capSample * matCapColor * matCapIntensity * shadowFactor;
}


//  5. NORMAL MAP

// TBN 재구성 후 탄젠트 공간 노멀 → 월드 공간 변환.
// normalWS / tangentWS / bitangentWS 는 호출 전에 normalize 완료 가정.

half3 GetNormalFromMap(TEXTURE2D_PARAM(normalMap, sampler_normalMap),
                       float2 uv,
                       float3 normalWS, float3 tangentWS, float3 bitangentWS)
{
    half4 normalSample = SAMPLE_TEXTURE2D(normalMap, sampler_normalMap, uv);
    half3 normalTS     = UnpackNormal(normalSample);           // DXT5nm / BC5 모두 처리
    // 행: T, B, N  →  열벡터 변환과 동일 (row-major TBN)
    half3 normalOut = normalTS.x * (half3)tangentWS
                    + normalTS.y * (half3)bitangentWS
                    + normalTS.z * (half3)normalWS;
    return normalize(normalOut);
}


//  5. RIM LIGHT
//  lightColor 제거: _RimColor가 씬 라이트에 끌려가지 않고 아티스트 지정 색 그대로 출력.
//  shadowFactor 제거: 그림자 영역 여부와 무관하게 실루엣에 항상 표시.
//  (툰셰이더에서 Rim Light는 조명 계산이 아닌 실루엣 강조 표현)

half3 GetRimLight(half3 normalWS, half3 viewDirWS,
                  half3 rimColor,
                  half rimPower, half rimIntensity)
{
    half ndotv   = saturate(dot(normalWS, viewDirWS));
    half fresnel = pow(1.0h - ndotv, rimPower);
    return fresnel * rimColor * rimIntensity;
}


//  5-1. RIM SHADE
//  RimLight의 반대 — 실루엣 가장자리를 어둡게 (Multiply 방식).
//  Additive로 검정을 더해도 변화 없으므로 Multiply가 유일한 선택.
//  LilToon 방식 참고: Border(Threshold) + Blur(Smoothness)로 툰 경계 생성.
//  Cull Back 불투명 메시라 abs(NdotV) 불필요 — 표준 NdotV 사용.

half GetRimShade(half3 normalWS, half3 viewDirWS, half3 lightDirWS,
                 half rimShadePower,
                 half rimShadeThreshold, half rimShadeSmoothness,
                 half rimShadeIntensity)
{
    half ndotv   = saturate(dot(normalWS, viewDirWS));
    half fresnel = pow(1.0h - ndotv, rimShadePower);
    // GetCelShadingSmooth 재사용: threshold/smoothness로 툰 경계 생성
    half rim     = GetCelShadingSmooth(fresnel, rimShadeThreshold, rimShadeSmoothness);
    // 빛 반대편(그림자 측) 실루엣에만 적용 — RimLight(밝게)와 같은 자리에서 상쇄되지 않도록.
    //   NdotL=1(정면광)→0, NdotL=-1(역광/그림자측)→1
    half darkSide = saturate(0.5h - 0.5h * dot(normalWS, lightDirWS));
    return rim * rimShadeIntensity * darkSide;
}


//  6. SPECULAR (Blinn-Phong, Hard-Edge)
//  NdotH 기반 스펙큘러. smoothstep으로 경계를 끊어 셀 애니 스타일.

half ToonSpecular(half3 normalWS, half3 viewDirWS, half3 lightDirWS,
                  half specularSize, half specularSmoothness)
{
    half3 halfVec = normalize(lightDirWS + viewDirWS);
    half  NdotH   = saturate(dot(normalWS, halfVec));
    half  spec    = pow(NdotH, specularSize);
    return smoothstep(0.5 - specularSmoothness, 0.5 + specularSmoothness, spec);
}


//  7. KAJIYA-KAY 헤어 하이라이트
//  T: 탄젠트, H: 하프 벡터
//  shift: 밴드 위치 오프셋, exponent: 선명도
//
//  [로직]
//    TdotH + shift → sinTH = sqrt(1 - TdotH²)
//    dirAtten으로 역광 억제 → pow(sinTH, exponent)

float CalculateKajiyaKay(float3 T, float3 H, float shift, float exponent)
{
    float TdotH    = dot(T, H) + shift;
    float sinTH    = sqrt(saturate(1.0 - TdotH * TdotH));
    float dirAtten = smoothstep(-1.0, 0.0, TdotH);
    return pow(saturate(sinTH), exponent) * dirAtten;
}


//  8. ALPHA CUTOUT
//  _UseAlphaClip ON → alpha < cutoff 픽셀 제거.
//  ForwardLit / ShadowCaster / DepthOnly 공통 — 셋이 동일한 기준으로 잘라야
//  그림자·깊이가 본체 실루엣과 일치함.

void FeelAlphaClip(float alpha, float useAlphaClip, float cutoff)
{
    if (useAlphaClip > 0.5)
        clip(alpha - cutoff);
}


#endif // FEEL_FUNCTIONS_INCLUDED
