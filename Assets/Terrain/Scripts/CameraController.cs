using UnityEngine;

public class CameraController : MonoBehaviour
{
    public GameObject cam;

    public Vector3 centerPoint;

    public float height;
    public float minHeight;
    public float maxHeight;
    public float deltaHeight;
    
    
    public float rotationSpeed = 100f;
    private float yaw = 0f; 
    private float pitch = 45f; 
    
    public float minPitch = 10f; 
    public float maxPitch = 80f;  
    
    public float distance = 20f;  // How far camera is from center point
    public float deltaDistance;
    public float maxDistance;
    public float minDistance;

    public void Update()
    {
        // W/S for height
        if (Input.GetKey(KeyCode.W))
        {
            height += deltaHeight * Time.deltaTime;

            if (height > maxHeight)
            {
                height = maxHeight;
            }
        }
        
        if (Input.GetKey(KeyCode.S))
        {
            height -= deltaHeight * Time.deltaTime;

            if (height < minHeight)
            {
                height = minHeight;
            }
        }
        
        // Scroll wheel for distance
        if (Input.GetAxis("Mouse ScrollWheel") < 0.0f)
        {
            distance += deltaDistance * Time.deltaTime;

            if (distance > maxDistance)
            {
                distance = maxDistance;
            }
        }
        
        if (Input.GetAxis("Mouse ScrollWheel") > 0.0f)
        {
            distance -= deltaDistance * Time.deltaTime;

            if (distance < minDistance)
            {
                distance = minDistance;
            }
        }
        
        if (Input.GetMouseButton(0)) // Left mouse button
        {
            yaw += Input.GetAxis("Mouse X") * rotationSpeed * Time.deltaTime;
            pitch -= Input.GetAxis("Mouse Y") * rotationSpeed * Time.deltaTime;
            
            // Clamp pitch to prevent flipping
            pitch = Mathf.Clamp(pitch, minPitch, maxPitch);
        }
        
        UpdateRotationAndPos();
    }

    public void UpdateRotationAndPos()
    {
        centerPoint = new Vector3(0, height, 0);
        
        // Calculate camera position based on rotation
        Quaternion rotation = Quaternion.Euler(pitch, yaw, 0);
        Vector3 offset = rotation * new Vector3(0, 0, -distance);
        
        cam.transform.position = centerPoint + offset;
        cam.transform.LookAt(centerPoint);
    }
}
