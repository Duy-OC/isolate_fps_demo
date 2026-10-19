# Kết quả benchmark (đo thật)

> **Cảnh báo:** mọi số liệu trong file này PHẢI do ứng dụng đo thật trên
> thiết bị/emulator. Không được chép số liệu mô phỏng từ báo cáo nháp.

## Phương pháp

- Bấm **Run all modes 3–5 lần** (Main → compute → Isolate, nghỉ 1 s giữa
  các lần). Lần đầu là **khởi động nóng**; ghi **trung vị** của các lần
  còn lại.
- Trước mỗi lần đo, app tự warm cache tệp (đọc bất đồng bộ) để chế độ đo
  đầu không bị bất lợi do đọc lạnh.
- Ba chế độ chạy trên cùng thiết bị, cùng tệp JSON, cùng hàm `parseJsonFile`.
- Ứng dụng tự sinh tệp JSON (20/40/50 MB, seed 42) vào thư mục tạm hoặc
  dùng tệp do người dùng chọn (không commit tệp lên git).

## Cấu hình máy đo

| Hạng mục | Giá trị |
|---|---|
| Thiết bị / Emulator | *(điền: tên máy thật hoặc AVD, API level)* |
| CPU / RAM | *(điền)* |
| Build mode | `flutter run --profile` (hoặc `--release` nếu profile không chạy được) |
| Flutter / Dart | *(điền, ví dụ: Flutter 3.47.7 • Dart 3.13.5)* |
| Kích thước tệp | *(điền: 20/40/50 MB hoặc tệp người dùng, số MB thật)* |
| Ngày đo | *(điền)* |

> **Lưu ý về emulator:** Flutter khuyến nghị đo trên **thiết bị thật**.
> Nếu đo trên emulator, ghi rõ: giá trị tuyệt đối không đại diện máy
> thật, nhưng **so sánh tương đối** giữa 3 chế độ vẫn hợp lệ.

## Kết quả

*(Chạy app → Run all modes ×3–5 → Copy Markdown → dán vào đây)*

| Chế độ | Wall ms | FPS TB | FPS min | Frame dài nhất (ms) | Vsync bỏ lỡ | Nodes |
|---|---|---|---|---|---|---|
| Main thread | | | | | | |
| compute() | | | | | | |
| Isolate (SendPort) | | | | | | |

## Ảnh biểu đồ

*(Chạy `flutter run --profile` → Run all modes lần 2 → chụp ảnh biểu đồ
gộp 3 đường → lưu vào `docs/images/`)*

## Nhận xét

*(Điền sau khi có số liệu thật: ví dụ đường Main tụt về 0 FPS đúng khoảng
đứng hình; compute/Isolate giữ gần 60; Isolate có progress bar, compute
không.)*
