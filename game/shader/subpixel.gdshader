shader_type canvas_item;

// 宣告一個變數，用來接收外部傳來的小數點偏移量
uniform vec2 cam_offset = vec2(0.0, 0.0);

void vertex() {
    // 將整個渲染畫面的頂點位置加上偏移量
    VERTEX += cam_offset;
}