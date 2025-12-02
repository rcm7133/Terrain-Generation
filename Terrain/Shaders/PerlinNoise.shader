Shader "Custom/PerlinNoise"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Amplitude ("Scale", float) = 15.0
        _Frequency ("Frequency", float) = 1.0
        _Seed ("Seed", Float) = 0
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
            float _Amplitude;
            float _Frequency;
            float _Seed;
            
            // Shuffles the input value to create randomness
            uint pcg_hash(uint input)
            {
                uint seed_val = (uint)(_Seed);
                uint seed_hash = seed_val * 747796405u + 2891336453u;
                seed_hash = ((seed_hash >> ((seed_hash >> 28u) + 4u)) ^ seed_hash) * 277803737u;
                seed_hash = (seed_hash >> 22u) ^ seed_hash;
                
                uint state = (input + seed_hash) * 747796405u + 2891336453u;
                uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
                return (word >> 22u) ^ word;
            }

            // Convert PCG Hash to value from 0-1
            float hash_to_float(uint input)
            {
                return (float)input / 4294967295.0; // divide by max uint value
            }
            
            // Get random gradient vector2 from values of -1 to 1
            float2 gradient_from_hash(uint h)
            {
                float angle = (float)h / 4294967295.0 * 6.2831853;
                return float2(cos(angle), sin(angle));
            }
            
            float fade(float t)
            {
                return t * t * t * (t * (t * 6 - 15) + 10);
            }
            
            float perlin_noise(float2 input, float frequency, float amplitude)
            {
                float2 uv = input / frequency;

                // Calculate min and max X and Y for the box
                uint floor_x = floor(uv.x);
                uint ceil_x = floor_x + 1;
                uint floor_y = floor(uv.y);
                uint ceil_y = floor_y + 1;
                
                // Get hash values for each corner
                uint h00 = pcg_hash(floor_x + floor_y * 73856093);
                uint h10 = pcg_hash(ceil_x + floor_y * 73856093);
                uint h01 = pcg_hash(floor_x + ceil_y * 73856093);
                uint h11 = pcg_hash(ceil_x + ceil_y * 73856093);
                
                float2 f = frac(uv);
                
                // Gradient Vectors
                float2 g00 = gradient_from_hash(h00);
                float2 g01 = gradient_from_hash(h01);
                float2 g10 = gradient_from_hash(h10);
                float2 g11 = gradient_from_hash(h11);
                
                // Offset vectors from corners to interpolated point
                float2 d00 = float2(f.x,     f.y);
                float2 d10 = float2(f.x - 1, f.y);
                float2 d01 = float2(f.x,     f.y - 1);
                float2 d11 = float2(f.x - 1, f.y - 1);
                
                float sx = fade(f.x);
                float sy = fade(f.y);

                // Bilinear interpolation
                float lerp_bottom_x = lerp(dot(g00, d00), dot(g10, d10), sx);
                float lerp_top_x = lerp(dot(g01, d01), dot(g11, d11), sx);

                float noise = lerp(lerp_bottom_x, lerp_top_x, sy);
                
                // Remap from [-1, 1] to [0, 1]
                noise = noise * 0.5 + 0.5;

                return noise * amplitude;
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
                return perlin_noise(i.uv, _Frequency, _Amplitude);
            }
            ENDCG
        }
    }
}
