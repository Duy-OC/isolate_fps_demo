# Cơ sở lý thuyết: Single-thread, Event loop, Isolate

> Biên soạn lại từ Chương 2 của báo cáo đề tài. Đây là lý thuyết nền tảng
> giúp hiểu vì sao Isolate giải quyết được vấn đề UI đứng hình.

## 1. Single-thread vs Multi-thread

Luồng (thread) là chuỗi lệnh được hệ điều hành lập lịch chạy. Chương trình
đơn luồng làm từng việc một; việc nào chạy lâu sẽ chặn mọi việc phía sau.

| Tiêu chí | Thread truyền thống (Java, C++) | Isolate (Dart) |
|---|---|---|
| Bộ nhớ | Chia sẻ heap giữa các thread | Mỗi isolate có heap riêng |
| Đồng bộ hóa | Cần lock/mutex; dễ race condition | Không cần lock (không shared mutable state) |
| Giao tiếp | Đọc/ghi biến chung | Truyền thông điệp qua port (copy) |
| Rủi ro chính | Lỗi đồng bộ khó tái hiện | Chi phí sao chép + chi phí khởi tạo |

Trong Flutter, mã Dart mặc định chạy trong **main isolate** (UI isolate).
Muốn có thêm "luồng" cho mã Dart, ta tạo thêm isolate.

## 2. Event loop của Dart

Mỗi isolate chạy một event loop: xử lý hết microtask rồi lấy tiếp event từ
hàng đợi sự kiện (chạm màn hình, timer, I/O, vsync, thông điệp từ isolate
khác). Mọi handler chạy tuần tự, không bị ngắt giữa chừng.

**Hiểu lầm phổ biến:** `async/await` và `Future` **không tạo luồng mới**.
Một đoạn code đồng bộ tốn CPU (ví dụ `jsonDecode` 20 MB) đặt trong hàm
`async` vẫn chặn event loop từ lúc chạy tới lúc xong.

## 3. Ngân sách khung hình – vì sao UI bị nghẽn

Ở 60 Hz, mỗi vsync cách nhau `1000/60 ≈ 16,67 ms`. Trong khoảng đó UI
thread phải build, layout, paint rồi chuyển cho Raster thread. Handler nặng
hơn ngân sách ⇒ vsync bị bỏ lỡ ⇒ animation đứng, chạm không phản hồi.
Tác vụ 2 000 ms ≈ 120 khung hình không được vẽ.

## 4. Isolate: bản chất

Một Isolate gồm: (1) heap riêng, (2) event loop riêng, (3) một luồng thực
thi lấy từ thread pool của Dart VM, (4) các port nhận thông điệp. Hai
isolate không thể giữ tham chiếu tới đối tượng của nhau.

- **Isolate group** (Dart ≥ 2.15): isolate sinh ra từ cùng chương trình
  dùng chung mã đã biên dịch → `Isolate.spawn` nhanh và ít RAM hơn. Heap
  vẫn tách biệt.
- Hàm khởi chạy phải là **top-level hoặc static** (hoặc closure chỉ bắt
  giá trị gửi được).

## 5. Bộ nhớ độc lập

Vì heap không chia sẻ, biến top-level/static là **riêng cho từng isolate**:
isolate mới khởi tạo lại giá trị mặc định, không kế thừa giá trị hiện tại
của isolate gọi. Danh sách gửi qua `SendPort` là **bản sao** – sửa ở worker
không ảnh hưởng main:

```dart
int counter = 0;                                // top-level: every isolate has its OWN copy
void worker(SendPort p) { p.send(counter); }    // worker sees 0, not main's value
// main: counter = 42; Isolate.spawn(worker, port.sendPort); -> receives 0
```

Hệ quả: không có race condition trên dữ liệu ứng dụng; dữ liệu dùng ở
isolate khác phải được gửi đi (copy); đối tượng giữ tài nguyên native
(socket, ReceivePort đã đóng) không gửi được.

## 6. Giao tiếp: SendPort / ReceivePort

| Thành phần | Vai trò |
|---|---|
| `ReceivePort` | "Hộp thư đến" – một Stream, gọi `.listen(...)` để nhận |
| `SendPort` | "Địa chỉ gửi thư" trỏ tới một ReceivePort; chính nó cũng gửi được qua port |
| `Isolate.spawn(entry, msg)` | Tạo isolate chạy hàm `entry` với tham số `msg` (thường là SendPort) |
| `Isolate.exit(port, msg)` | Kết thúc isolate và chuyển thông điệp không sao chép (zero-copy) |

Kiểu gửi được: `null, bool, num, String, List, Map, Set, SendPort,
TransferableTypedData`, đối tượng lớp thường (Dart ≥ 2.15).

Mẫu **handshake hai chiều** dùng trong app: main truyền `SendPort` của mình
cho worker; worker tạo `ReceivePort` riêng rồi gửi `SendPort` ngược về main;
từ đó hai chiều: main gửi lệnh/đường dẫn, worker gửi tiến độ và kết quả.

## 7. compute() và Isolate.run()

`compute(callback, message)` chạy hàm top-level trong isolate tạm rồi trả
kết quả qua Future (dùng `Isolate.exit` nên gần như không copy). `Isolate.run()`
là API cùng ý tưởng ở tầng Dart.

| Cách | Progress / hủy | Khi nào dùng |
|---|---|---|
| Main thread | – | Việc rất nhẹ (< vài ms) |
| `compute()` / `Isolate.run()` | Không | Tác vụ "một phát": parse, nén, lọc ảnh |
| `Isolate.spawn` + Port | Có | Worker sống lâu, cần progress, hủy, nhiều lệnh |

## 8. Chi phí và hạn chế

- **Chi phí khởi tạo:** sinh isolate mất vài–vài chục ms; tác vụ rất ngắn
  có thể lỗ.
- **Chi phí sao chép:** gửi cấu trúc lớn tốn thời gian tỉ lệ kích thước.
  Nên gửi kết quả tổng hợp; dùng `Isolate.exit`/`compute` hoặc
  `TransferableTypedData` cho dữ liệu nhị phân lớn.
- **Plugin/platform channel:** isolate nền không tự dùng được plugin; cần
  `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` với
  `RootIsolateToken` (Flutter ≥ 3.7). Không dùng được `dart:ui`/widget.
- **Flutter Web:** không có isolate song song thật; `compute` chạy trên
  luồng chính → không có lợi ích.
- **Không phải thuốc tiên:** nếu nút thắt ở build/paint thì isolate không
  giúp.

## 9. Chọn công cụ nào?

| Tình huống | Gợi ý |
|---|---|
| Việc nhẹ, < 5 ms | Chạy thẳng trên main |
| Một tác vụ nặng chạy một lần | `compute()` hoặc `Isolate.run()` |
| Cần progress, hủy, nhiều lệnh | `Isolate.spawn` + SendPort/ReceivePort |
| Rất nhiều tác vụ nhỏ liên tục | Worker sống lâu / pool isolate |
