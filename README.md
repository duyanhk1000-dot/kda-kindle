# KDA Kindle — Ultra-Light Gateway for Kindle Touch 4

Gateway đọc báo tiếng Việt, truyện chữ và truyện tranh tối ưu hóa cho trình duyệt cổ trên **Kindle Touch 4th Gen (Firmware 5.3.7.3)**.

## Phase 0: Compatibility Lab
Trang phòng thí nghiệm kiểm thử khả năng hiển thị thực tế trên Kindle Touch 4:
- Đường dẫn: `/lab` (hoặc `/lab/index.html`)
- Nội dung kiểm thử:
  1. Font tiếng Việt UTF-8 (ký tự đặc biệt & dấu tổ hợp).
  2. Kích thước font chữ (14px, 18px, 22px, 26px) & khoảng cách dòng `line-height`.
  3. Cảm ứng nút bấm (vùng chạm min 40px).
  4. Hiển thị ảnh JPEG Grayscale `max-width: 100%`.
  5. Khả năng cuộn trang văn bản dài trên E-Ink.

## Hạ Tầng Phase 0
- **HTML/CSS tĩnh thuần 100%**, không JavaScript, không React/Vue, không Server Node/Hono, không Supabase Database.
- Triển khai trực tiếp lên Vercel từ GitHub Repository: `duyanhk1000-dot/kda-kindle`.
