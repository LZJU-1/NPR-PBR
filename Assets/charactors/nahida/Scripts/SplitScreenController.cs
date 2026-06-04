using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>
/// 屏幕分割线 — 左键旋转（绕屏幕中心）、右键平移、R 重置。
/// </summary>
public class SplitScreenController : MonoBehaviour
{
    public Color lineColor = Color.white;
    public float lineThickness = 3f;
    [Range(-1f, 1f)] public float lineOffset = 0f;  // 距屏幕中心的垂直距离 [-1,1]
    [Range(0f, 360f)] public float lineAngle = 0f;   // 线方向角度

    private bool _rotating, _panning;
    private float _lastMouseX;

    void Update()
    {
        var m = Mouse.current;
        var k = Keyboard.current;
        if (m == null) return;

        if (k != null && k.rKey.wasPressedThisFrame) { lineOffset = 0; lineAngle = 0; }

        if (m.leftButton.wasPressedThisFrame)  { _rotating = true;  _lastMouseX = m.position.x.ReadValue(); }
        if (m.leftButton.wasReleasedThisFrame) { _rotating = false; }
        if (m.rightButton.wasPressedThisFrame) { _panning  = true;  _lastMouseX = m.position.x.ReadValue(); }
        if (m.rightButton.wasReleasedThisFrame) { _panning  = false; }

        if (_rotating)
        {
            float dx = m.position.x.ReadValue() - _lastMouseX;
            lineAngle += dx * 0.3f;
            lineAngle = (lineAngle % 360 + 360) % 360;
            _lastMouseX = m.position.x.ReadValue();
        }
        if (_panning)
        {
            float dx = m.position.x.ReadValue() - _lastMouseX;
            lineOffset = Mathf.Clamp(lineOffset + dx / Screen.width * 2f, -1f, 1f);
            _lastMouseX = m.position.x.ReadValue();
        }
    }

    void OnGUI()
    {
        GUILayout.BeginArea(new Rect(10, 10, 280, 50));
        GUILayout.Box(string.Format("Angle: {0:F0}  Offset: {1:F2}", lineAngle, lineOffset));
        GUILayout.Label("Left-drag: Rotate | Right-drag: Pan | R: Reset");
        GUILayout.EndArea();
    }
}
