# Fractional Brownian Motion Terrain Generation

<img width="857" height="756" alt="snow" src="https://github.com/user-attachments/assets/d1fd8327-2077-470a-b19e-fd8f9b13b877" />

## How to use

1. Open Unity Hub (Unity 6+) and use the add button to add the files to your projects.

<img width="1008" height="585" alt="hub" src="https://github.com/user-attachments/assets/ef036e3f-76bd-43fa-9a4a-7363118bfc63" />

2. Load the project. In the Hierarchy in the top left click on the MeshGenerator game object. The inspector on the right side of the screen will now show options for terrain generation.

<img width="779" height="707" alt="inspector2" src="https://github.com/user-attachments/assets/a567160a-9fc9-48d3-a6bf-23f53b4c7b62" />

3. Press play in the top middle of the screen. A terrain mesh should appear in the game view. Playing with the terrain settings will change the output of the mesh.

5. Once the mesh is as desired, in the inspector click on the "Bake Mesh to Asset" button on the bottom of the terrain settings. This will generate a folder with the mesh name. In it will be the baked mesh, heightmap, and texture.

## Controls
- W/S:  move up and down vertically
- Left Click and Drag:  rotate around the mesh
- Scroll Wheel: Zoom closer/farther from the mesh

# How does this work?

We start by generating a mesh to work with. We'll create an nxm mesh, where n and m are vertex counts. This gives us a flat plane with any vertices to apply a height offset to. The higher the vertex count means more data to work and better visuals with the tradeoff of worse performance. To instantly see changes to our terrain settings we will render the height of each vertex on the GPU in the vertex shader. Once we're happy with the terrain we will bake the height of the vertices using the CPU. This will take some time up front but will save us from having to calculate the height continuously on the GPU.

<img width="984" height="1045" alt="nxntris" src="https://github.com/user-attachments/assets/7b40408e-08ea-4608-9a03-fa3d8393478f" />

But how do we generate convincing height values for each vertex? 

## Noise

Using a noise function with the UV values of the texture coordinate as the input will allow us to generate the height of a vertex. To make a very simple noise function we will need to make use of a Hash Function. The defining characteristic of a Hash Function is producing very different outputs for very similar inputs. For example if f(x) is our hash function, f(2.0) = 1412 and f(2.01) = 25. This will give us a seemingly random output given and input, however the same input will have the same output. We will use PCG Hash for this example. We will clamp the values of the output of the hash to 0-1.0 for our sake. Now if we generate a texture and use the UV texture coordinates as inputs of the Hash Function we will end up with this output:

<img width="641" height="664" alt="simpleNoise" src="https://github.com/user-attachments/assets/7a2575fc-42d3-46d0-a346-5b8d3dff38e6" />

This output gives us a very basic white noise texture. However if we were to sample this texture and use the sampled value to change the height of the vertex we would end up with an unappealing result.

<img width="991" height="1083" alt="noisyTer" src="https://github.com/user-attachments/assets/6376acd7-8c2e-4de5-af60-58c8bbe1f733" />

The problem is that when we sample the UV coordinates (values of 0.0-1.0) we are given wildly different height values from our Hash Function. For the terrain to be convincing we want very similar values for similar inputs. Then why are we using a Hash Function in the first place? The randomness of the Hash is useful if we have our input as whole numbers. Once we have the height of each whole number we can interpolate between two points to get a value that lies between them. To do this we will take the floor and ceiling of our input and blend between our two points. The difference between the 2 points is found with x - \lfloor x \rfloor.

The equation for the x coordinate is noise(x) = hash(⌊x⌋) + (x - ⌊x⌋) * (hash*(⌈x⌉) - hash(⌊x⌋)). This is known as **Linear Interpolation** aka Lerping.

<img width="871" height="609" alt="grid" src="https://github.com/user-attachments/assets/ba94a608-3a13-41d8-b4da-1c05605ec91a" />
__Credit: Acerola https://www.youtube.com/@Acerola_t__

We'll extend this logic to apply to the y axis as well and imagine our texture sample as a grid with corners of n00 = <⌊x⌋, ⌊y⌋>, n10 = <⌈x⌉, ⌊y⌋>, n01 = <⌊x⌋, ⌈y⌉>, and n11 = <⌈x⌉, ⌈y⌉.
To get our noise value we will Lerp between the bottom two points (n00 and n10) and Lerp between the top two points (n01 and n11). We will then Lerp between those two values, giving us the noise value.

Lerping between two the two axes is called **Bilinear Interpolation**. 

Here is the whole equation: Noise(x, y) = Lerp(Lerp(n00, n01, x - ⌊x⌋), Lerp(n10, n11, x - ⌊x⌋), y - ⌊y⌋).

This is called Value Noise and it looks like this:

<img width="685" height="662" alt="valueNoSmoothstep" src="https://github.com/user-attachments/assets/3e0ddb0d-5d2e-429d-be08-3be76968ced4" />

While it doesn't look fantastic, it is smoother than raw white noise. If we apply smoothstep to the fractional x and y components we are given a slightly smoother output:

<img width="628" height="658" alt="valueNoise" src="https://github.com/user-attachments/assets/b9631d9a-0ae9-4177-b249-a03cbaf92264" />

To make a better noise function we need to apply gradient vectors to each point on the grid structure. A gradient vector points in the direction of most change. A gradient vector is defined as: G = <[-1, 1], [-1, 1]>. It's a two component vector with random values upon initialization. 

<img width="646" height="570" alt="dot" src="https://github.com/user-attachments/assets/d140778e-1c73-46ab-a7ba-a0668243e0cf" />

For each corner we will take the dot product of the gradient vector (g) and the direction from the corner to the point x,y (d). We then Bilinearly Interpolate between the four dot products in the same pattern as before:

Noise(x, y) = Lerp(Lerp(dot(g00, d00), dot(g10, d10), smoothstep(x - ⌊x⌋)), Lerp(dot(g01, d01), dot(g11, d11), smoothstep(x - ⌊x⌋)), smoothstep(y - ⌊y⌋)).

The output of this noise function onto a texture give us **Perlin Noise**:

<img width="659" height="662" alt="perlinNoise" src="https://github.com/user-attachments/assets/749480c3-202f-4156-b110-f01cc4bbe3ea" />

Perlin Noise looks far more organic than the previous noise functions we have tried. If we apply the output of the Perlin Noise to the plane we generated we get:

<img width="824" height="653" alt="Applied Perlin" src="https://github.com/user-attachments/assets/4bf86530-80ad-4b53-b7b0-b5db38a360e5" />

Now we're starting to get decent results. If we apply two variables to our height function:

Height(u,v) = Amplitude * PerlinNoise(uv * Frequency)

We get more control over our terrain. These two variables operate like they would with a sine or cosine function. Amplitude controls the height of the terrain peaks and frequency controls the density of the noise in the output. Here is an example with low frequency and high amplitude:

<img width="779" height="637" alt="lowFreqHighAmp" src="https://github.com/user-attachments/assets/154a4969-24de-4fb5-9d58-70da45720107" />}

This provides high terrain with low details and bumps. Here is an example of high frequency and low amplitude:

<img width="848" height="673" alt="highFLowA" src="https://github.com/user-attachments/assets/ed9ad0ae-a202-4d50-a966-ba51868e03d0" />

This produces terrain with low peaks but a very bumpy and detailed surface. What if we had a way to combine the large peaks of the low frequency high amplitude terrain and the detail of the high frequency low amplitude terrain?

## Fractional Brownian Motion

If we sum multiple Perlin Noise functions with varying amplitudes and frequencies we will combine their output and gain the detail and height we're looking for. We will add two more variables to our simulation. The Iteration count will determine how many Perlin functions we will add together. The Lacunarity will determine how the decay and growth of the amplitude and the frequency will behave. The higher the Lacunarity the faster the decay of the amplitude and the faster the growth of the frequency with each iteration. This will effectively add many Perlin functions that will decrease in height but grow in detail. The sum of these functions with decay and growth is called **Fractional Brownian Motion**.

Here is a demo of increasing Iterations:

![Desktop2025 12 02-23 10 09 01-ezgif com-video-to-gif-converter](https://github.com/user-attachments/assets/250f28aa-c58c-4962-bbc0-888a516bbea2)

Here is a demo of increasing Lacunarity:

![Desktop2025 12 02-23 21 44 02-ezgif com-video-to-gif-converter](https://github.com/user-attachments/assets/96249d34-7b4d-4999-89ae-6b179a804a0c)

## Snow

By taking the dot product between the surface normal and the world Up vector (0, 1, 0) we can get the angle between the two vectors. We can apply a cutoff and add a snow color if the angle is above the cutoff. Its crude but applies snow to the mesh:

<img width="857" height="756" alt="snow" src="https://github.com/user-attachments/assets/7f68f228-f052-47d6-849e-b54fcca2ded3" />

## Potential Improvements

This implementation is just a base for future features. It is far from being game ready. If we look at the triangles on the final baked mesh we can see it is far too dense to be performant:

<img width="1016" height="949" alt="tris" src="https://github.com/user-attachments/assets/1f9cd849-bf23-4072-994d-792fa74096ff" />

By reducing the triangle count on the baked mesh we can greatly improve performance.

Another potential improvement would be implementing Hydraulic Erosion. This simulates the erosion of rock from water over many iterations. It would edit the heightmap and bake the mesh to the new height map. There are practically limitless improvements to be made from here. 

## Credits
http://youtube.com/watch?v=J1OdPrO7GD0& 
https://www.youtube.com/watch?v=DxUY42r_6Cg& 
PCG Hash: https://stackoverflow.com/questions/23319289/is-there-a-good-glsl-hash-function 
Noise: https://arxiv.org/html/2403.08782v1


