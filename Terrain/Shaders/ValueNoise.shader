Shader "Custom/ValueNoise"
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
            float hash_to_float(uint input)
            {
                return (float)input / 4294967295.0; // divide by max uint value
            }
            
            float value_noise(v2f i)
            {
                float2 uv = i.uv * 10000;

                // Bilinear Interpolation
                
                uint floor_x = floor(uv.x);
                uint ceil_x = uv.x + 1;

                uint floor_y = floor(uv.y);
                uint ceil_y = uv.y + 1;

                uint h00 = pcg_hash(floor_x + floor_y * 73856093); // Multiply by large prime number
                uint h10 = pcg_hash(ceil_x + floor_y * 73856093);
                uint h01 = pcg_hash(floor_x + ceil_y * 73856093);
                uint h11 = pcg_hash(ceil_x + ceil_y * 73856093);
                
                float p00 = hash_to_float(h00);
                float p10 = hash_to_float(h10);
                float p01 = hash_to_float(h01);
                float p11 = hash_to_float(h11);
                
                float2 f = frac(uv);

                float fractional_x = f.x;
                
                float lerp_bottom_x = lerp(p00, p10, smoothstep(0.0 , 1.0, fractional_x));
                float lerp_top_x = lerp(p01, p11, smoothstep(0.0 , 1.0, fractional_x));

                float fractional_y = f.y;
                
                float sy = smoothstep(0.0, 1.0, fractional_y);
                
                return lerp(lerp_bottom_x, lerp_top_x, sy);
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
                
                return value_noise(i);
            }
            ENDCG
        }
    }
}
