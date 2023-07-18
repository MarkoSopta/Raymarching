using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter
{
    [SerializeField]
    private Shader _shader;

    public Material _raymarchMaterial
    {
        get {
            if (!_raymarchMat && _shader) {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return _raymarchMat;
        }

    }
    private Material _raymarchMat;

    public Camera _camera {
        get {
            if (!_cam) {
                _cam = GetComponent<Camera>();
            }
            return _cam;
        }
    }
    private Camera _cam;
    [Header("Setup")]
    public float _maxDistance;
    [Range(1, 300)]
    public int _maxIterations;
    [Range(0.1f, 0.001f)]
    public float _accuracy;

    [Header("Ambient Occlusion")]
    public int _aoIterations;
    public float _aoStepSize, _aoIntensity;
    

    [Header("Light")]
    public Transform _directionalLight;
    public Color _lightColor;
    public float _lightIntensity;

    [Header("Shadow")]
    public float _shadowIntensity;
    public Vector2 _shadowDistance;
    [Range(1, 256)]
    public float _penumbra;
[Header("Signed Distance Field")]    
    public Color _mainColor;
    public Vector4 _sphere1;
    public Vector4 _box1;
    public float _roundingFactor;
    public float _smoothingFactor;
    public Vector4 _sphere2;
    public float _intersectionSmoothing;


    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        if (!_raymarchMaterial) {
            Graphics.Blit(source, destination);
            return;
        }
        _raymarchMat.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMaterial.SetFloat("_maxDistance", _maxDistance);
        _raymarchMaterial.SetFloat("_accuracy", _accuracy);
        _raymarchMaterial.SetInt("_maxIterations", _maxIterations);

        _raymarchMaterial.SetFloat("_aoIntensity", _aoIntensity);
        _raymarchMaterial.SetFloat("_aoStepSize", _aoStepSize);
        _raymarchMaterial.SetInt("_aoIterations", _aoIterations);

        _raymarchMaterial.SetVector("_sphere1", _sphere1);        
        _raymarchMaterial.SetVector("_sphere2", _sphere2);
        _raymarchMaterial.SetVector("_box1", _box1);

        _raymarchMaterial.SetFloat("_roundingFactor", _roundingFactor);
        _raymarchMaterial.SetFloat("_smoothingFactor", _smoothingFactor);
        _raymarchMaterial.SetFloat("_intersectionSmoothing", _intersectionSmoothing);

        _raymarchMaterial.SetColor("_lightColor", _lightColor);
        _raymarchMaterial.SetFloat("_lightIntensity", _lightIntensity);

        _raymarchMaterial.SetVector("_shadowDistance", _shadowDistance);
        _raymarchMaterial.SetFloat("_shadowIntensity", _shadowIntensity);
        _raymarchMaterial.SetFloat("_penumbra", _penumbra);

        _raymarchMaterial.SetVector("_lightDirection", _directionalLight ? _directionalLight.forward : Vector3.down);
        _raymarchMaterial.SetColor("_mainColor", _mainColor);
        RenderTexture.active = destination;
        _raymarchMaterial.SetTexture("_MainTex", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        _raymarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //bottom left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //bottom right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //top right
        GL.MultiTexCoord2(0 , 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //top left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);


        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam) {

        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * .5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);


        return frustum;
    
    }
}
