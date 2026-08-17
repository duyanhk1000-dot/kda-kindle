const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const ROOT = __dirname;

// Mock Data for Phase 1 Reader Core
const MOCK_NEWS = [
    {
        id: "n1",
        title: "Dự báo thời tiết 3 miền: Không khí lạnh tăng cường, nhiều nơi có mưa",
        source: "VnExpress",
        date: "17/08/2026",
        image: "/images/test-grayscale.jpg",
        content: [
            "Theo Trung tâm Dự báo Khí tượng Thủy văn Quốc gia, hiện nay bộ phận không khí lạnh đang tiếp tục di chuyển xuống phía Nam.",
            "Dự báo trên đất liền, khoảng chiều và đêm nay, bộ phận không khí lạnh này sẽ ảnh hưởng đến khu vực phía Đông Bắc Bộ, sau đó ảnh hưởng đến Bắc Trung Bộ, một số nơi ở phía Tây Bắc Bộ và Trung Trung Bộ.",
            "Gió Đông Bắc trong đất liền mạnh lên cấp 3, vùng ven biển cấp 4-5. Nhiệt độ thấp nhất ở Bắc Bộ và Bắc Trung Bộ phổ biến từ 14-17 độ, vùng núi Bắc Bộ phổ biến 11-14 độ, vùng núi cao có nơi dưới 10 độ."
        ]
    },
    {
        id: "n2",
        title: "Thị trường công nghệ: Xu hướng thiết bị e-ink tối giản gia tăng",
        source: "Tuổi Trẻ",
        date: "17/08/2026",
        image: "/images/test-grayscale.jpg",
        content: [
            "Các thiết bị sử dụng màn hình E-Ink đang quay trở lại mạnh mẽ nhờ khả năng bảo vệ mắt và thời lượng pin vượt trội.",
            "Nhiều người dùng chọn tận dụng lại các máy đọc sách Kindle đời cũ để biến thành cổng đọc tin tức tối giản, giúp giảm thời gian nhìn vào màn hình smartphone rực rỡ."
        ]
    }
];

const MOCK_BOOKS = [
    {
        id: "b1",
        title: "Phàm Nhân Tu Tiên",
        author: "Vong Ngữ",
        category: "Tiên Hiệp",
        totalChapters: 2450,
        description: "Một thiếu niên bình thường ở thôn quê tên Hàn Lập, tình cờ bước vào một môn派 nhỏ ở giang hồ, bắt đầu con đường tu tiên đầy chông gai...",
        chapters: [
            { num: 1, title: "Chương 001: Sơn Thôn Thiếu Niên", content: "Hàn Lập ngẩng đầu nhìn bầu trời đêm rực rỡ ánh sao, trong lòng trào dâng một cảm giác xa xăm. Tu tiên một đường đầy rẫy chông gai, gian khổ không sao kể xiết. Từ một thiếu niên bình thường ở Nam Bình thôn, trải qua bao nhiêu sóng gió hiểm trở, hắn mới bước được tới ngày hôm nay.\n\nGió đêm thổi qua tán lá trúc phát ra tiếng rì rào như tiếng sóng biển. Hàn Lập siết chặt tay, bình tĩnh điều hòa nhịp thở. Trong túi trữ vật của hắn, chiếc Chưởng Thiên Bình nhỏ bé vẫn đang âm thầm hấp thu nguyệt hoa giữa đêm tĩnh mịch." },
            { num: 2, title: "Chương 002: Thất Huyền Môn", content: "Thất Huyền Môn nằm ở ngọn núi Thái Nam, địa thế hiểm trở. Hàn Lập cùng người bạn thân Trương Thiết được đưa lên núi từ sáng sớm..." },
            { num: 3, title: "Chương 003: Mặc Bác Sĩ", content: "Mặc Bác Sĩ là một người trung niên sắc mặt xám xịt, ánh mắt thâm trầm sắc bén..." }
        ]
    }
];

const MOCK_COMICS = [
    {
        id: "c1",
        title: "Đô Thị Tu Tiên (Manga)",
        author: "Cửu Luyện",
        chapter: 1,
        totalPages: 3,
        pages: ["/images/test-grayscale.jpg", "/images/test-grayscale.jpg", "/images/test-grayscale.jpg"]
    }
];

// Helper Layout Generator for Kindle HTML4
function renderKindlePage(title, bodyContent) {
    return `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>${title}</title>
<link rel="stylesheet" href="/css/kindle.css">
</head>
<body>
<h1>KDA KINDLE READER</h1>
<table class="kindle-nav">
<tr>
<td><a href="/"><b>[1. BÁO CHÍ]</b></a></td>
<td><a href="/books"><b>[2. TRUYỆN CHỮ]</b></a></td>
<td><a href="/comics"><b>[3. TRUYỆN TRANH]</b></a></td>
</tr>
</table>
<hr>

${bodyContent}

<hr>
<table class="kindle-nav">
<tr>
<td><a href="/"><b>[VỀ TRANG CHỦ]</b></a></td>
<td><a href="#top"><b>[VỀ ĐẦU TRANG ▲]</b></a></td>
</tr>
</table>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
    const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.searchParams;

    // Static Assets (.css, .jpg)
    if (pathname.startsWith('/css/') || pathname.startsWith('/images/')) {
        const filePath = path.join(ROOT, pathname);
        if (fs.existsSync(filePath)) {
            const ext = path.extname(filePath).toLowerCase();
            const contentType = ext === '.css' ? 'text/css; charset=utf-8' : 'image/jpeg';
            res.writeHead(200, { 'Content-Type': contentType });
            fs.createReadStream(filePath).pipe(res);
            return;
        }
    }

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });

    // ROUTE: Home
    if (pathname === '/') {
        let content = `<h2>BÁO CHÍ MỚI NHẤT</h2><div class="test-box">`;
        MOCK_NEWS.forEach(item => {
            content += `<p>• <a href="/news/detail?id=${item.id}"><b>${item.title}</b></a> <br><small>Nguồn: ${item.source} (${item.date})</small></p>`;
        });
        content += `</div><h2>TRUYỆN CHỮ NỔI BẬT</h2><div class="test-box">`;
        MOCK_BOOKS.forEach(item => {
            content += `<p>• <a href="/book/detail?id=${item.id}"><b>${item.title}</b></a> - <i>${item.category}</i> (${item.totalChapters} chương)</p>`;
        });
        content += `</div><h2>TRUYỆN TRANH (MANGA)</h2><div class="test-box">`;
        MOCK_COMICS.forEach(item => {
            content += `<p>• <a href="/comic/detail?id=${item.id}"><b>${item.title}</b></a> (Chương 1)</p>`;
        });
        content += `</div>`;
        return res.end(renderKindlePage("KDA Kindle Gateway", content));
    }

    // ROUTE: News List
    if (pathname === '/news') {
        let content = `<h2>DANH SÁCH BÁO CHÍ</h2><div class="test-box">`;
        MOCK_NEWS.forEach(item => {
            content += `<p>• <a href="/news/detail?id=${item.id}"><b>${item.title}</b></a><br><i>${item.source} - ${item.date}</i></p>`;
        });
        content += `</div>`;
        return res.end(renderKindlePage("KDA News", content));
    }

    // ROUTE: News Detail
    if (pathname === '/news/detail') {
        const newsId = query.get('id');
        const article = MOCK_NEWS.find(n => n.id === newsId) || MOCK_NEWS[0];
        let content = `<h2>${article.title}</h2>
        <p><b>Nguồn: ${article.source} | Ngày: ${article.date}</b></p>
        <img src="${article.image}" alt="Article Image">
        <div class="test-box">`;
        article.content.forEach(p => {
            content += `<p>${p}</p>`;
        });
        content += `</div><p><a href="/news" class="btn">[◄ Về Danh Sách Báo]</a></p>`;
        return res.end(renderKindlePage(article.title, content));
    }

    // ROUTE: Books List
    if (pathname === '/books') {
        let content = `<h2>DANH SÁCH TRUYỆN CHỮ</h2><div class="test-box">`;
        MOCK_BOOKS.forEach(b => {
            content += `<p>• <a href="/book/detail?id=${b.id}"><b>${b.title}</b></a> - Tác giả: ${b.author} (${b.category})</p>`;
        });
        content += `</div>`;
        return res.end(renderKindlePage("KDA Books", content));
    }

    // ROUTE: Book Detail & Chapters
    if (pathname === '/book/detail') {
        const bookId = query.get('id');
        const book = MOCK_BOOKS.find(b => b.id === bookId) || MOCK_BOOKS[0];
        let content = `<h2>${book.title}</h2>
        <p><b>Tác giả: ${book.author} | Thể loại: ${book.category}</b></p>
        <p>${book.description}</p>
        <h3>DANH SÁCH CHƯƠNG</h3>
        <div class="test-box">`;
        book.chapters.forEach(c => {
            content += `<p>• <a href="/book/chapter?id=${book.id}&chap=${c.num}"><b>${c.title}</b></a></p>`;
        });
        content += `</div>`;
        return res.end(renderKindlePage(book.title, content));
    }

    // ROUTE: Chapter Reader
    if (pathname === '/book/chapter') {
        const bookId = query.get('id');
        const chapNum = parseInt(query.get('chap') || '1');
        const book = MOCK_BOOKS.find(b => b.id === bookId) || MOCK_BOOKS[0];
        const chapter = book.chapters.find(c => c.num === chapNum) || book.chapters[0];

        const prevChap = chapNum > 1 ? chapNum - 1 : null;
        const nextChap = chapNum < book.chapters.length ? chapNum + 1 : null;

        let navButtons = `<p>`;
        if (prevChap) navButtons += `<a href="/book/chapter?id=${book.id}&chap=${prevChap}" class="btn">[◄ Chương ${prevChap}]</a> `;
        navButtons += `<a href="/book/detail?id=${book.id}" class="btn">[Danh Sách Chương]</a> `;
        if (nextChap) navButtons += `<a href="/book/chapter?id=${book.id}&chap=${nextChap}" class="btn">[Chương ${nextChap} ►]</a>`;
        navButtons += `</p>`;

        let content = `<h2>${book.title}</h2>
        <h3>${chapter.title}</h3>
        ${navButtons}
        <div class="test-box font-normal">`;
        chapter.content.split('\n\n').forEach(p => {
            content += `<p>${p}</p>`;
        });
        content += `</div>${navButtons}`;
        return res.end(renderKindlePage(`${book.title} - ${chapter.title}`, content));
    }

    // ROUTE: Comics List & Reader
    if (pathname === '/comics' || pathname === '/comic/detail') {
        const comic = MOCK_COMICS[0];
        const pageNum = parseInt(query.get('page') || '1');
        const totalPages = comic.totalPages;

        const prevPage = pageNum > 1 ? pageNum - 1 : null;
        const nextPage = pageNum < totalPages ? pageNum + 1 : null;

        let navButtons = `<p style="text-align: center;">`;
        if (prevPage) navButtons += `<a href="/comic/detail?id=${comic.id}&page=${prevPage}" class="btn">[◄ Trang Trước]</a> `;
        navButtons += `<b>Trang ${pageNum} / ${totalPages}</b> `;
        if (nextPage) navButtons += `<a href="/comic/detail?id=${comic.id}&page=${nextPage}" class="btn">[Trang Sau ►]</a>`;
        navButtons += `</p>`;

        let content = `<h2>${comic.title} (Chương 1)</h2>
        ${navButtons}
        <img src="${comic.pages[pageNum - 1]}" alt="Comic Page ${pageNum}">
        ${navButtons}`;
        return res.end(renderKindlePage(`${comic.title} - Trang ${pageNum}`, content));
    }

    // 404 Fallback
    res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(renderKindlePage("404 Not Found", "<h2>404 Trang không tồn tại</h2><p><a href='/'>[Về trang chủ]</a></p>"));
});

server.listen(PORT, () => {
    console.log(`KDA Kindle Reader Gateway running on http://localhost:${PORT}`);
});
