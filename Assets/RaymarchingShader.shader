Shader "Marko/RaymarchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

                #include "UnityCG.cginc"
                #include "DistanceFunctions.cginc"
            sampler2D _MainTex;

            //Setup           
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform int _maxIterations;
            uniform float _accuracy;
            uniform float _maxDistance;

            //Color
            uniform fixed4 _groundColor;    
            uniform fixed4 _sphereColor[8];
            uniform float _colorIntensity;

            //Light
            uniform float3 _lightDirection,  _lightColor;
            uniform float _lightIntensity;

            //Shadows
            uniform float2 _shadowDistance;
            uniform float _shadowIntensity , _penumbra;
            //Reflections

            uniform int _reflectionCount;
            uniform float _reflectionIntensity;
            uniform float _enviromentReflectionIntensity;
            uniform samplerCUBE _reflectionCube;

            //Signed Distance Functions
            uniform float4 _sphere;
            uniform int _numOfSpheres;
            uniform float _sphereSmooth;
            uniform float _rotation;


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = _CamFrustum[(int)index].xyz;
                o.ray /= abs(o.ray.z);
                o.ray = mul(_CamToWorld, o.ray);

                return o;
            }


            float3 RotateY(float3 v, float degree) {
            
                float rad = 0.0174532925 * degree;
                float cosY = cos(rad);
                float sinY = sin(rad);
                return float3(cosY * v.x - sinY * v.z, v.y,  sinY * v.x + cosY * v.z);

            }


           
                float4 distanceField(float3 p)             
            {                
                float4 groundPlane = float4 (_groundColor.rgb, sdPlane(p, float4(0, 1, 0,0)));
                float4 sphere = float4(_sphereColor[0].rgb, sdSphere(p - _sphere.xyz, _sphere.w));
                for (int i = 1; i < _numOfSpheres; i++)
                {
                    float4 addSphere = float4(_sphereColor[i].rgb, sdSphere(RotateY(p, _rotation * i) - _sphere.xyz, _sphere.w));
                    sphere = opUS(sphere, addSphere, _sphereSmooth);
                }
                return opU(sphere, groundPlane);
            }

            float3 getNormal(float3 p)
            {
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    distanceField(p + offset.xyy).w - distanceField(p - offset.xyy).w,
                    distanceField(p + offset.yxy).w - distanceField(p - offset.yxy).w,
                    distanceField(p + offset.yyx).w - distanceField(p - offset.yyx).w);
                return normalize(n);
            }

            float hardShadows(float3 ro, float3 rd, float mint, float maxt)
            {            
                for (float t = mint; t < maxt; t++)
                {
                    float h = distanceField(ro + rd * t).w;
                    if (h < 0.001) {
                        return 0.0;
                    }
                    t += h;
                }
                return 1.0;
            }



            float softShadows(float3 ro, float3 rd, float mint, float maxt, float k)
            {
                float result = 1.0;
                for (float x = mint; x < maxt;)
                {
                    float h = distanceField(ro + rd * x).w;
                    if (h < 0.001) {
                        return 0.0;
                    }
                    result = min(result, k * h / x);
                    x += h;
                }
                return result;
            }

            uniform float _aoStepSize, _aoIntensity;;
            uniform int _aoIterations;

            float ambientOcclusion(float3 pos, float3 norm) {

                float step = _aoStepSize;
                float ao = 0.0;
                float dst;

                for (int i = 1; i <= _aoIterations; i++)
                {
                    dst = step * i;
                    ao += max(0.0,(dst - distanceField(pos + norm + dst).w) / dst);
                }
                return (1.0 - ao * _aoIntensity);
            }




            float3 Shading(float3 position, float3 normal, fixed3 c) {

                float3 result; 
                //Diffuse Color
                float3 color = c.rgb * _colorIntensity;
                //Directional light
                float3 light = (_lightColor * dot(-_lightDirection, normal) * .5 + .5) * _lightIntensity;
                //Shadows
                float shadow = softShadows(position, -_lightDirection, _shadowDistance.x, _shadowDistance.y, _penumbra) * .5 + .5;
                shadow = max(0.0, pow(shadow, _shadowIntensity));
                //Ambioent Occlusion
                float ao = ambientOcclusion(position, normal);


                result = color * shadow * light * ao;
                return result;
            }


            //interesting effect when you set the shadow distance x to 0.001




            bool Raymarching(float3 rayOrigin,float3 rayDistance,float depth, float maxDistance, int maxIter, inout float3 p, inout fixed3 distColor) {

                bool hit;
                maxIter = _maxIterations;
                float t = 0; //distance travelled along the ray

                for (int i  = 0; i < maxIter; i++)   
                {
                    if (t > _maxDistance || t>= depth) 
                    {                    
                        hit = false;
                        break;
                    }
                    p = rayOrigin + rayDistance * t;

                    float4 d = distanceField(p);
                    if (d.w < _accuracy) //hit
                    {       
                        distColor = d.rgb;
                        hit = true;
                        break;
                    }
                    t += d.w;
                }
                return hit;            
            }
            

            fixed4 frag(v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);


               fixed3 col = tex2D(_MainTex,i.uv);
               float3 rayDirection = normalize(i.ray.xyz);
               float3 rayOrigin = _WorldSpaceCameraPos;
               fixed4 result;               
               float3 hitPos;
               fixed3 distColor;

               bool hit = Raymarching(rayOrigin, rayDirection, depth, _maxDistance, _maxIterations, hitPos, distColor);
               if (hit)
               { 

               float3 normal = getNormal(hitPos);
               float3 shade = Shading(hitPos, normal, distColor);
               result = fixed4(shade, 1);
               result += fixed4(texCUBE(_reflectionCube, normal).rgb * _enviromentReflectionIntensity * _reflectionIntensity, 0);
               
               if (_reflectionCount > 0) {
                   rayDirection = normalize(reflect(rayDirection, normal));
                   rayOrigin = hitPos + rayDirection * .01;

                   hit = Raymarching(rayOrigin, rayDirection, _maxDistance, _maxDistance * .5, _maxIterations / 2, hitPos, distColor);
                   if (hit) {
                       float3 normal = getNormal(hitPos);
                       float3 shade = Shading(hitPos, normal, distColor);
                       result += fixed4(shade * _reflectionIntensity, 0);
                     }
                }
               if (_reflectionCount > 1) {
                   rayDirection = normalize(reflect(rayDirection, normal));
                   rayOrigin = hitPos + rayDirection * .01;

                   hit = Raymarching(rayOrigin, rayDirection, _maxDistance, _maxDistance * .25, _maxIterations / 4, hitPos , distColor);
                   if (hit) {
                       float3 normal = getNormal(hitPos);
                       float3 shade = Shading(hitPos, normal, distColor);
                       result += fixed4(shade * _reflectionIntensity * .5, 0);
                        }
                    }
               if (_reflectionCount > 2) {
                   rayDirection = normalize(reflect(rayDirection, normal));
                   rayOrigin = hitPos + rayDirection * .01;

                   hit = Raymarching(rayOrigin, rayDirection, _maxDistance, _maxDistance * .125, _maxIterations / 8, hitPos, distColor);
                   if (hit) {
                       float3 normal = getNormal(hitPos);
                       float3 shade = Shading(hitPos, normal, distColor);
                       result += fixed4(shade * _reflectionIntensity * .25, 0);
                   }
               }
               }
               else {
                   result = fixed4(0,0,0,0);
               }
               
               return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
