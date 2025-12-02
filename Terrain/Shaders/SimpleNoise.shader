Shader "Custom/SimpleNoise"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            fixed4 _Color;
            sampler2D _MainTex;
            
            // Shuffles the input value to create randomness
            uint pcg_hash(uint input)
            {
                uint state = input * 747796405u + 2891336453u;
                uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
                return (word >> 22u) ^ word;
            }

            // Convert PCG Hash to value from 0-1
            float clamped_pcg_hash(uint input)
            {
                return (float)input / 4294967295.0; // divide by max uint value
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv; 
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * _Color; // Sample texture and apply color
                
                float2 uv = i.uv * 10000;

                uint hashInput = uint(uv.x) * 73856093u ^ uint(uv.y) * 19349663u;
                
                float noise = clamped_pcg_hash(pcg_hash(hashInput));
                
                return noise * col;
            }
            ENDCG
        }
    }
}
