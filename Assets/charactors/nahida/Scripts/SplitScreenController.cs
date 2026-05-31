using UnityEngine;
using UnityEngine.InputSystem;

public class SplitScreenController : MonoBehaviour
{
    [Range(-1f, 1f)] public float lineOffset  = 0f;
    [Range(0f, 360f)] public float lineAngle  = 0f;
    public Color lineColor = Color.white;
    public float lineThickness = 3f;

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
        if (m.rightButton.wasPressedThisFrame)  { _panning = true;  _lastMouseX = m.position.x.ReadValue(); }
        if (m.rightButton.wasReleasedThisFrame) { _panning = false; }

        if (_rotating)
        {
            float dx = m.position.x.ReadValue() - _lastMouseX;
            lineAngle += dx * 0.3f;
            if (lineAngle < 0) lineAngle += 360; else if (lineAngle > 360) lineAngle -= 360;
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
        float rad = lineAngle * Mathf.Deg2Rad;
        Vector2 dir = new Vector2(Mathf.Cos(rad), Mathf.Sin(rad));
        float cx = Screen.width * 0.5f;
        float cy = Screen.height * 0.5f;
        float offsetPx = lineOffset * Screen.width * 0.5f;
        Vector2 perpDir = new Vector2(-dir.y, dir.x);
        Vector2 center = new Vector2(cx, cy) + perpDir * offsetPx;
        float length = Mathf.Sqrt(Screen.width * Screen.width + Screen.height * Screen.height) * 2f;
        float angle = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;

        var prevColor = GUI.color;
        GUI.color = lineColor;
        var oldMatrix = GUI.matrix;
        GUIUtility.RotateAroundPivot(angle, center);
        GUI.DrawTexture(new Rect(center.x - length * 0.5f, center.y - lineThickness * 0.5f, length, lineThickness), Texture2D.whiteTexture);
        GUI.matrix = oldMatrix;
        GUI.color = prevColor;

        GUILayout.BeginArea(new Rect(10, 10, 280, 50));
        GUILayout.Box(string.Format("Angle: {0:F0}  Offset: {1:F2}", lineAngle, lineOffset));
        GUILayout.Label("Left-drag: Rotate | Right-drag: Pan | R: Reset");
        GUILayout.EndArea();
    }
}
