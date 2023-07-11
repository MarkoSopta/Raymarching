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
            #pragma target 3.0

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _maxDistance;
            uniform float4 _sphere1;
            uniform float3 _lightDirection;

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

            float sdSphere(float3 p, float s) {

                return length(p) - s;
            }

            



            float distanceField(float3 p) 
            {
                float Sphere1 = sdSphere(p - _sphere1.xyz, _sphere1.w);

                return Sphere1;
            }

            float3 getNormal(float3 p)
            {
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
                    distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
                    distanceField(p + offset.yyx) - distanceField(p - offset.yyx));
                return normalize(n);
            }


            fixed4 Raymarching(float3 ro,float3 rd) {

                fixed4 result = fixed4(1, 1, 1, 1);
                const int maxIter = 128;
                float t = 0; //distance travelled along the ray

                for (int i  = 0; i < maxIter; i++)   
                {
                    if (t > _maxDistance) 
                    {                    
                        result = fixed4(rd, 1);
                        break;
                    }
                    float3 p = ro + rd * t;

                    float d = distanceField(p);
                    if (d < 0.01) //hit
                    { 
                        float3 n = getNormal(p);
                        float light = dot(-_lightDirection, n);
                        result = fixed4(1,1,1, 1)* light;
                        break;
                    }
                    t += d;
                }
                return result;            
            }
            

            fixed4 frag(v2f i) : SV_Target
            {
               float3 rayDirection = normalize(i.ray.xyz);
               float3 rayOrigin = _WorldSpaceCameraPos;
               fixed4 result = Raymarching(rayOrigin, rayDirection);
               return result;
            }
            ENDCG
        }
    }
}
