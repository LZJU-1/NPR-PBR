using UnityEngine;

/// <summary>
/// 屏幕分割线控制器 — 鼠标拖拽旋转和平移分割线。
/// 分割线一侧显示 NPR，另一侧显示 PBR（当前均为 NPR 测试）。
///
/// 操作：
///   左键拖拽 → 旋转分割线
///   右键拖拽 → 平移分割线
///   鼠标滚轮 → 缩放
///   R 键 → 重置
/// </summary>
public class SplitScreenController : MonoBehaviour
{
    [Header("分割线参数")]
    [Range(-1f, 1f)] public float lineOffset = 0f;   // 分割线偏离屏幕中心的距离
    [Range(0f, 360f)] public float lineAngle  = 0f;    // 分割线旋转角度

    [Header("显示")]
    public Material splitMaterial; // 全屏分割合成材质

    private bool  _dragging;
    private bool  _rotating;
    private float _lastMouseX;

    void Update()
    {
        HandleInput();

        // 传入 Shader（用全局参数，SplitScreenRendererFeature 读取）
        float rad = lineAngle * Mathf.Deg2Rad;
        Vector2 lineDir = new Vector2(Mathf.Cos(rad), Mathf.Sin(rad));
        Shader.SetGlobalFloat("_SplitLineOffset", lineOffset);
        Shader.SetGlobalVector("_SplitLineDir", lineDir);
    }

    void HandleInput()
    {
        // R 键重置
        if (Input.GetKeyDown(KeyCode.R))
        {
            lineOffset = 0f;
            lineAngle = 0f;
        }

        // 滚轮缩放（效果等同于调线宽度）
        if (Input.mouseScrollDelta.y != 0)
        {
            // 预留
        }

        // 左键拖拽 = 旋转
        if (Input.GetMouseButtonDown(0)) { _rotating = true; _lastMouseX = Input.mousePosition.x; }
        if (Input.GetMouseButtonUp(0))   { _rotating = false; }

        // 右键拖拽 = 平移
        if (Input.GetMouseButtonDown(1)) { _dragging = true; _lastMouseX = Input.mousePosition.x; }
        if (Input.GetMouseButtonUp(1))   { _dragging = false; }

        if (_rotating)
        {
            float dx = Input.mousePosition.x - _lastMouseX;
            lineAngle += dx * 0.3f;
            if (lineAngle < 0f) lineAngle += 360f;
            if (lineAngle > 360f) lineAngle -= 360f;
            _lastMouseX = Input.mousePosition.x;
        }

        if (_dragging)
        {
            float dx = Input.mousePosition.x - _lastMouseX;
            lineOffset += dx / Screen.width * 2f;
            lineOffset = Mathf.Clamp(lineOffset, -1f, 1f);
            _lastMouseX = Input.mousePosition.x;
        }
    }

    void OnGUI()
    {
        // 简单的提示
        GUILayout.BeginArea(new Rect(10, 10, 300, 100));
        GUILayout.Label($"分割线角度: {lineAngle:F0}°  偏移: {lineOffset:F2}");
        GUILayout.Label("左键拖拽=旋转 | 右键拖拽=平移 | R=重置");
        GUILayout.EndArea();
    }
}
