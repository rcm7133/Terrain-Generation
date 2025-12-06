Shader "Custom/UnifiedTerrain"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Amplitude ("Amplitude", Float) = 15.0
        _Frequency ("Frequency", Float) = 1.0
        _Lacunarity ("Lacunarity", Int) = 2
        _Iterations ("Iterations", Int) = 8
        _Seed ("Seed", Float) = 0
        _LightDir ("Light Direction", Vector) = (0,1,0,0)
        
        _SnowTex ("Snow Texture", 2D) = "white" {}
        _OverlayColor ("Overlay Color", Color) = (1., 1., 1., 1.)
        _SlopeThreshold ("Slope Cutoff Threshold", float) = 1.0
        _SnowBlendRange ("Snow Blend Range", Range(0.0, 0.5)) = 0.15
        _SnowNoiseScale ("Snow Noise Scale", Float) = 10.0 
        _SnowNoiseStrength ("Snow Noise Strength", Range(0.0, 1.0)) = 0.3
        _MainTexTiling ("Main Texture Tiling", Float) = 10.0
        _SnowTexTiling ("Snow Texture Tiling", Float) = 10.0
        
    }

    SubShader
    {
        // Pass 1 Heightmap
        Pass
        {
            Name "Heightmap"
            ZWrite Off Cull Off ZTest Always

            CGPROGRAM
            #pragma vertex vert_fullscreen
            #pragma fragment frag_heightmap

            float _Amplitude;
            float _Frequency;
            int _Lacunarity;
            int _Iterations;
            float _Seed;

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            
            // Noise functions 
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

                uint floor_x = floor(uv.x);
                uint ceil_x  = floor_x + 1;
                uint floor_y = floor(uv.y);
                uint ceil_y  = floor_y + 1;

                uint h00 = pcg_hash(floor_x + floor_y * 73856093);
                uint h10 = pcg_hash(ceil_x + floor_y * 73856093);
                uint h01 = pcg_hash(floor_x + ceil_y * 73856093);
                uint h11 = pcg_hash(ceil_x + ceil_y * 73856093);

                float2 f = frac(uv);

                float2 g00 = gradient_from_hash(h00);
                float2 g10 = gradient_from_hash(h10);
                float2 g01 = gradient_from_hash(h01);
                float2 g11 = gradient_from_hash(h11);

                float2 d00 = float2(f.x,     f.y);
                float2 d10 = float2(f.x - 1, f.y);
                float2 d01 = float2(f.x,     f.y - 1);
                float2 d11 = float2(f.x - 1, f.y - 1);

                float sx = fade(f.x);
                float sy = fade(f.y);

                float lerp_bottom = lerp(dot(g00,d00), dot(g10,d10), sx);
                float lerp_top    = lerp(dot(g01,d01), dot(g11,d11), sx);

                float noise = lerp(lerp_bottom, lerp_top, sy);

                return (noise * 0.5 + 0.5) * amplitude; // map [-1,1] -> [0,1]
            }

            float fbm(float2 uv)
            {
                float value = 0.0;
                float amplitude = _Amplitude;
                float frequency = _Frequency;

                for (int i = 0; i < _Iterations; i++)
                {
                    value += perlin_noise(uv * frequency, 1.0, amplitude);
                    frequency *= _Lacunarity;
                    amplitude *= 0.5; // Gain
                }

                return value;
            }
            
            v2f vert_fullscreen(uint id : SV_VertexID)
            {
                float2 uv = float2((id << 1) & 2, id & 2);
                v2f o;
                o.vertex = float4(uv * 2 - 1, 0, 1);
                o.uv = uv;
                return o;
            }

            float4 frag_heightmap(v2f i) : SV_Target
            {
                float h = fbm(i.uv);
                return float4(h, h, h, 1);
            }
            ENDCG
        }
        
        // Pass 2 Terrain Visuals
        Pass
        {
            Name "Visualization"

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
                float3 normal : TEXCOORD1;
            };

            sampler2D _MainTex;
            float _Amplitude;
            float _Frequency;
            int _Lacunarity;
            int _Iterations;
            float _Seed;
            float3 _LightDir;
            fixed4 _Color;
            float _OverlayMinApplyAngle;
            fixed4 _OverlayColor;
            float _SlopeThreshold;
            sampler2D _SnowTex;
            float _SnowBlendRange;
            float _SnowNoiseScale;
            float _SnowNoiseStrength;
            float _MainTexTiling;
            float _SnowTexTiling;


            // Noise functions
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

                uint floor_x = floor(uv.x);
                uint ceil_x  = floor_x + 1;
                uint floor_y = floor(uv.y);
                uint ceil_y  = floor_y + 1;

                uint h00 = pcg_hash(floor_x + floor_y * 73856093);
                uint h10 = pcg_hash(ceil_x + floor_y * 73856093);
                uint h01 = pcg_hash(floor_x + ceil_y * 73856093);
                uint h11 = pcg_hash(ceil_x + ceil_y * 73856093);

                float2 f = frac(uv);

                float2 g00 = gradient_from_hash(h00);
                float2 g10 = gradient_from_hash(h10);
                float2 g01 = gradient_from_hash(h01);
                float2 g11 = gradient_from_hash(h11);

                float2 d00 = float2(f.x,     f.y);
                float2 d10 = float2(f.x - 1, f.y);
                float2 d01 = float2(f.x,     f.y - 1);
                float2 d11 = float2(f.x - 1, f.y - 1);

                float sx = fade(f.x);
                float sy = fade(f.y);

                float lerp_bottom = lerp(dot(g00,d00), dot(g10,d10), sx);
                float lerp_top    = lerp(dot(g01,d01), dot(g11,d11), sx);

                float noise = lerp(lerp_bottom, lerp_top, sy);

                return (noise * 0.5 + 0.5) * amplitude;
            }

            float fbm(float2 uv)
            {
                float value = 0.0;
                float amplitude = _Amplitude;
                float frequency = _Frequency;

                for (int i = 0; i < _Iterations; i++)
                {
                    value += perlin_noise(uv * frequency, 1.0, amplitude);
                    frequency *= _Lacunarity;
                    amplitude *= 0.5; // Gain
                }

                return value;
            }

            v2f vert(appdata v)
            {
                v2f o;
                float height = fbm(v.uv);

                // Normal Approx
                float e = 0.0001; // small offset
                
                float hx = fbm(v.uv + float2(e, 0));
                float hy = fbm(v.uv + float2(0, e));
                
                o.normal = normalize(float3(
                    height - hx,   // slope in X
                    2 * e,    // exaggerate vertical scale
                    height - hy    // slope in Y
                ));
                                
                float maxHeight = _Amplitude * 2.0;
                float centeredHeight = height - (maxHeight * 0.5);
                
                v.vertex.y += centeredHeight;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 lightDir = normalize(_LightDir);
                float diffuse = saturate(dot(i.normal, lightDir));
                float slope = saturate(dot(i.normal, float3(0,1,0)));

                float2 tiledUV_main = i.uv * _MainTexTiling;
                float2 tiledUV_snow = i.uv * _SnowTexTiling;

                fixed4 col = tex2D(_MainTex, tiledUV_main) * _Color;
                fixed4 snowCol = tex2D(_SnowTex, tiledUV_snow);
                
                float minThreshold = _SlopeThreshold - _SnowBlendRange;
                float maxThreshold = _SlopeThreshold + _SnowBlendRange;
                
                float snowBlend = 0.0;
                if (slope > minThreshold)
                {
                    snowBlend = smoothstep(minThreshold, maxThreshold, slope);
                }
                
                float4 finalColor = lerp(col, snowCol, snowBlend);
                return finalColor;
            }
            ENDCG
        }
        
        // Pass 3 - Diffuse/Albedo
        Pass
        {
            Name "Diffuse"
            ZWrite Off Cull Off ZTest Always

            CGPROGRAM
            #pragma vertex vert_diffuse
            #pragma fragment frag_diffuse

            struct v2f_diffuse
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float height : TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            float _Amplitude;
            float _Frequency;
            int _Lacunarity;
            int _Iterations;
            float _Seed;
            float3 _LightDir;
            float _SlopeThreshold;
            float4 _OverlayColor;
            sampler2D _SnowTex;
            float _SnowBlendRange;
            float _SnowNoiseScale;
            float _SnowNoiseStrength;
            float _MainTexTiling;
            float _SnowTexTiling;

            // Copy your noise functions here (pcg_hash, gradient_from_hash, fade, perlin_noise, fbm)
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
                uint floor_x = floor(uv.x);
                uint ceil_x  = floor_x + 1;
                uint floor_y = floor(uv.y);
                uint ceil_y  = floor_y + 1;

                uint h00 = pcg_hash(floor_x + floor_y * 73856093);
                uint h10 = pcg_hash(ceil_x + floor_y * 73856093);
                uint h01 = pcg_hash(floor_x + ceil_y * 73856093);
                uint h11 = pcg_hash(ceil_x + ceil_y * 73856093);

                float2 f = frac(uv);
                float2 g00 = gradient_from_hash(h00);
                float2 g10 = gradient_from_hash(h10);
                float2 g01 = gradient_from_hash(h01);
                float2 g11 = gradient_from_hash(h11);

                float2 d00 = float2(f.x,     f.y);
                float2 d10 = float2(f.x - 1, f.y);
                float2 d01 = float2(f.x,     f.y - 1);
                float2 d11 = float2(f.x - 1, f.y - 1);

                float sx = fade(f.x);
                float sy = fade(f.y);

                float lerp_bottom = lerp(dot(g00,d00), dot(g10,d10), sx);
                float lerp_top    = lerp(dot(g01,d01), dot(g11,d11), sx);
                float noise = lerp(lerp_bottom, lerp_top, sy);
                return (noise * 0.5 + 0.5) * amplitude;
            }

            float fbm(float2 uv)
            {
                float value = 0.0;
                float amplitude = _Amplitude;
                float frequency = _Frequency;

                for (int i = 0; i < _Iterations; i++)
                {
                    value += perlin_noise(uv * frequency, 1.0, amplitude);
                    frequency *= _Lacunarity;
                    amplitude *= 0.5;
                }
                return value;
            }
            
            v2f_diffuse vert_diffuse(uint id : SV_VertexID)
            {
                float2 uv = float2((id << 1) & 2, id & 2);
                
                v2f_diffuse o;
                o.vertex = float4(uv * 2 - 1, 0, 1);
                o.uv = uv;
                
                o.height = 0;
                o.normal = float3(0, 1, 0);
                
                return o;
            }

            fixed4 frag_diffuse(v2f_diffuse i) : SV_Target
            {
                // Calculate height and normal per pixel
                float height = fbm(i.uv);
                
                // Normal Approximation
                float e = 0.0001;
                float hx = fbm(i.uv + float2(e, 0));
                float hy = fbm(i.uv + float2(0, e));
                
                float3 normal = normalize(float3(
                    height - hx,
                    2 * e,
                    height - hy
                ));
                
                float slope = saturate(dot(normal, float3(0, 1, 0)));
                
                float2 tiledUV_main = i.uv * _MainTexTiling;
                float2 tiledUV_snow = i.uv * _SnowTexTiling;

                fixed4 col = tex2D(_MainTex, tiledUV_main) * _Color;
                fixed4 snowCol = tex2D(_SnowTex, tiledUV_snow);
              
                float minThreshold = _SlopeThreshold - _SnowBlendRange;
                float maxThreshold = _SlopeThreshold + _SnowBlendRange;
                
                float snowBlend = 0.0;
                if (slope > minThreshold)
                {
                    snowBlend = smoothstep(minThreshold, maxThreshold, slope);
                }
                
                float4 finalColor = lerp(col, snowCol, snowBlend);
                return finalColor;
                
            }
            ENDCG
        }
    }
}