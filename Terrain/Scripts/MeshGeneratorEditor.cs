using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(MeshGenerator))]
public class MeshGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        // Draw default inspector fields
        DrawDefaultInspector();

        MeshGenerator gen = (MeshGenerator)target;

        GUILayout.Space(10);

        if (GUILayout.Button("Bake Mesh to Asset"))
        {
            gen.SaveMesh();
        }
    }
}
