using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;

public class MeshGenerator : MonoBehaviour
{
    [Header("Width and Height of Mesh")]
    public int x;
    public int z;
    private float scale;
    [Header("Prototyping Material (Instant Feedback on changes with GPU)")]
    public Material meshMaterial;
    [Header("Terrain Settings")]
    [Range(0.0f, 50.0f)] public float amplitude = 3.5f;
    [Range(0.0f, 4.0f)] public float frequency = 1.5f;
    [Range(1, 10)] public float lacunarity = 2;
    [Range(1, 10)] public int iterations = 8;
    [Range(0.0f, 1.0f)] public float slopeColorThreshold = 0.75f;
        
    [Header("Saved Mesh Material")]
    public Material savedMeshMaterial;
    
    private RenderTexture heightmapRT;
    private RenderTexture diffuseRT;
    [Header("Height Map Resolution")]
    public int heightResolution;
    public int textureResolution;
    [Header("Height Map Resolution")]
    private Texture2D heightmap;
    private Texture2D texture;
    [Header("Terrain Texture")]
    public Texture2D mainTexture;
    [Range(1.0f, 100.0f)] public float mainTexTiling = 1.0f;
    [Header("Snow Texture")]
    public Texture2D snowTexture;
    [Range(0.01f, 10.0f)] public float snowTexTiling = 1.0f;
    [Range(0.01f, 1.0f)] public float snowBlendRange = 1.0f;
    
    [Header("Save Settings")]
    public string meshName;

    private Mesh gpuMesh;
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        scale = 1 / ((x + z) / 10.0f);
        
        gpuMesh = GeneratePlane();
        
        // Move plane to center of origin and account for offset
        transform.position = new Vector3(0 - ((float)x/2) * scale, 0, 0 - ((float)z/2) * scale);
        
        GetComponent<MeshRenderer>().material = meshMaterial;
        
        UpdateShaderProperties();
    }
    
    // Executes upon change in inspector values
    private void OnValidate()
    {
        UpdateShaderProperties();
    }

    public void UpdateShaderProperties()
    {
        meshMaterial.SetFloat("_Amplitude", amplitude);
        meshMaterial.SetFloat("_Frequency", frequency);
        meshMaterial.SetFloat("_Lacunarity", lacunarity);
        meshMaterial.SetInt("_Iterations", iterations);
        meshMaterial.SetTexture("_MainTex", mainTexture);
        meshMaterial.SetTexture("_SnowTex", snowTexture);
        meshMaterial.SetFloat("_SlopeThreshold", slopeColorThreshold);
        meshMaterial.SetFloat("_MainTexTiling",  mainTexTiling);
        meshMaterial.SetFloat("_SnowTexTiling",  snowTexTiling);
        meshMaterial.SetFloat("_SnowBlendRange", snowBlendRange);
    }

    public Mesh GeneratePlane()
    {
        Mesh mesh = new Mesh();
        
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

        mesh.name = meshName;
        
        Vector3[] verts = new Vector3[(x + 1) * (z + 1)];
        Vector2[] uvs = new Vector2[(x + 1) * (z + 1)];
        
        // Generate Verts and UVs
        for (int i = 0; i < z + 1; i++)
        {
            for (int j = 0; j < x + 1; j++)
            {
                int k = i * (x + 1) + j;
                
                verts[k] = new Vector3(j * scale, 0, i * scale);
                
                uvs[k] = new Vector2((float)j / x, (float)i / z);
            }
        }
        // Create tris
        int[] triangles = new int[x * z * 6];
        
        int t = 0;
        
        for (int i = 0; i < z; i++)
        {
            for (int j = 0; j < x; j++)
            {
                int k = i * (x + 1) + j;
                
                // First triangle
                triangles[t++] = k;
                triangles[t++] = k + x + 1;
                triangles[t++] = k + 1;

                // Second triangle
                triangles[t++] = k + 1;
                triangles[t++] = k + x + 1;
                triangles[t++] = k + x + 2;
            }
        }
        
        mesh.vertices = verts;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        
        GetComponent<MeshFilter>().mesh = mesh;

        return mesh;
    }
    
    public void BakeHeightmap(Mesh newMesh)
    {
        CreateHeightmapRT();
    
        Graphics.Blit(null, heightmapRT, meshMaterial, 0);
    
        Texture2D tex = new Texture2D(heightResolution, heightResolution, TextureFormat.RFloat, false);
        RenderTexture.active = heightmapRT;
        tex.ReadPixels(new Rect(0, 0, heightResolution, heightResolution), 0, 0);
        tex.Apply();
        RenderTexture.active = null;
    
        heightmap = tex;
    
        Vector3[] verts = newMesh.vertices;
        int vertsX = x + 1;
        int vertsZ = z + 1;

        for (int i = 0; i < vertsZ; i++)
        {
            for (int j = 0; j < vertsX; j++)
            {
                int k = i * vertsX + j;
                
                
                float u = Mathf.Clamp01((float)j / x);
                float v = Mathf.Clamp01((float)i / z);
                
                // Prevent edge corruption
                float h;
                if (u >= 0.999f || v >= 0.999f)
                {
                    // Sample without bilinear at edges
                    int px = Mathf.Min((int)(u * heightResolution), heightResolution - 1);
                    int py = Mathf.Min((int)(v * heightResolution), heightResolution - 1);
                    h = heightmap.GetPixel(px, py).r;
                }
                else
                {
                    h = heightmap.GetPixelBilinear(u, v).r;
                }

                verts[k].y = h;
            }
        }
    
        newMesh.vertices = verts;
        newMesh.RecalculateNormals();
        newMesh.RecalculateBounds();
    }
    
    public void CreateDiffuseRT()
    {
        if (diffuseRT == null || diffuseRT.width != textureResolution)
        {
            if (diffuseRT != null) diffuseRT.Release();
            
            diffuseRT = new RenderTexture(textureResolution, textureResolution, 0, RenderTextureFormat.ARGB32);
            diffuseRT.enableRandomWrite = true;
            diffuseRT.Create();
        }
    }
    
    public void BakeTexture()
    {
        CreateDiffuseRT();
        UpdateShaderProperties();
    
        // Render Pass 3 (Diffuse) to diffuseRT
        Graphics.Blit(null, diffuseRT, meshMaterial, 2);
    
        Texture2D tex = new Texture2D(textureResolution, textureResolution, TextureFormat.RGBA32, false);
    
        RenderTexture.active = diffuseRT;  
        tex.ReadPixels(new Rect(0, 0, textureResolution, textureResolution), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        texture = tex;

        Material newMaterial = new Material(Shader.Find("Standard"));
        newMaterial.mainTexture = tex;
    }

    public GameObject SaveMesh()
    {
        #if UNITY_EDITOR
        if (gpuMesh == null)
        {
            Debug.LogError("Must Save Mesh During Runtime!");
            return null;
        }
        
        System.IO.Directory.CreateDirectory("Assets/Terrain/Prefabs/" + meshName + "/");
        
        string prefabPath = EditorUtility.SaveFilePanelInProject(
            "Save Generated Mesh",
            meshName,
            "prefab", 
            "Choose a location for the mesh prefab.",
            "Assets/Terrain/Prefabs/" + meshName + "/"
        );

        if (string.IsNullOrEmpty(prefabPath))
            return null;

        string directory = System.IO.Path.GetDirectoryName(prefabPath);
        string meshPath = System.IO.Path.Combine(directory, meshName + "_Mesh.asset");
        string materialPath = System.IO.Path.Combine(directory, meshName + "_Material.mat");
        string diffusePath = System.IO.Path.Combine(directory, meshName + "_Diffuse.png");
        string heightmapPath = System.IO.Path.Combine(directory, meshName + "_HeightMap.png");

        // Create and bake mesh
        Mesh meshCopy = Instantiate(gpuMesh);
        meshCopy.name = meshName;
        BakeHeightmap(meshCopy);
        
        // Bake diffuse texture
        BakeTexture();
        
        // Save mesh asset
        AssetDatabase.CreateAsset(meshCopy, meshPath);
        
        // Save textures as PNG files
        SaveHeightmapPNG();
        SaveDiffusePNG();
        
        // Refresh to make sure Unity sees the new texture files
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        
        // Load the saved diffuse texture from disk
        Texture2D savedDiffuse = AssetDatabase.LoadAssetAtPath<Texture2D>(diffusePath);
        if (savedDiffuse == null)
        {
            Debug.LogError("Failed to load saved diffuse texture at: " + diffusePath);
            return null;
        }
        
        // Create new material instance and assign the saved texture
        Material newMaterial = new Material(savedMeshMaterial);
        newMaterial.name = meshName + "_Material";
        newMaterial.mainTexture = savedDiffuse;
        newMaterial.SetFloat("_Glossiness", 0f);
        
        // Save the material as an asset
        AssetDatabase.CreateAsset(newMaterial, materialPath);
        
        // Create GameObject with mesh and material
        GameObject tempObj = new GameObject(meshName);
        MeshFilter meshFilter = tempObj.AddComponent<MeshFilter>();
        MeshRenderer renderer = tempObj.AddComponent<MeshRenderer>();
        
        meshFilter.sharedMesh = meshCopy;
        renderer.sharedMaterial = newMaterial; 
        
        // Save as prefab
        GameObject prefab = PrefabUtility.SaveAsPrefabAsset(tempObj, prefabPath);

        // Clean up temporary object
        DestroyImmediate(tempObj);

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
    
        return prefab;
        #else
            return null;
        #endif
    }
    
    public void CreateHeightmapRT()
    {
        if (heightmapRT == null || heightmapRT.width != heightResolution)
        {
            if (heightmapRT != null) heightmapRT.Release();

            heightmapRT = new RenderTexture(heightResolution, heightResolution, 0, RenderTextureFormat.RFloat);
            heightmapRT.enableRandomWrite = true;
            heightmapRT.Create();
        }
    }
    
    public void SaveHeightmapPNG()
    {
        if (heightmap == null)
        {
            Debug.LogError("No heightmap texture to save!");
            return;
        }

        byte[] bytes = heightmap.EncodeToPNG();
        System.IO.Directory.CreateDirectory("Assets/Terrain/Prefabs/" + meshName + "/");
        string path = "Assets/Terrain/Prefabs/" + meshName + "/" + meshName + "HeightMap.png";
        System.IO.File.WriteAllBytes(path, bytes);
        AssetDatabase.Refresh();
        
        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer != null)
        {
            importer.maxTextureSize = 4096;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.isReadable = true;
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
        }
    }
    
    public void SaveDiffusePNG()
    {
        if (texture == null)
        {
            Debug.LogError("No diffuse texture to save!");
            return;
        }

        byte[] bytes = texture.EncodeToPNG();
        System.IO.Directory.CreateDirectory("Assets/Terrain/Prefabs/" + meshName + "/");
        string path = "Assets/Terrain/Prefabs/" + meshName + "/" + meshName + "_Diffuse.png";
        System.IO.File.WriteAllBytes(path, bytes);
        AssetDatabase.Refresh();

        // Configure import settings
        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer != null)
        {
            importer.maxTextureSize = 4096;  // Set max size to 4096
            importer.textureCompression = TextureImporterCompression.Uncompressed; 
            importer.isReadable = true; 
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
        }

    
        Debug.Log("Saved diffuse texture to: " + path);
    }
}
