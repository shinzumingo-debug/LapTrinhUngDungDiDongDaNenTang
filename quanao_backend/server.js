const express = require('express');
const cors = require('cors');
const sql = require('mssql');

const app = express();
app.use(cors());
app.use(express.json());

// CẤU HÌNH KẾT NỐI DATABASE VỚI WINDOWS AUTHENTICATION (HOẶC TÀI KHOẢN SA)
const dbConfig = {
    user: 'sa',
    password: '123456', // Thay bằng mật khẩu bạn vừa đặt
    server: 'localhost',
    database: 'QuanLyKinhDoanhQuanAo',
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// MIDDLEWARE XÁC THỰC QUYỀN ADMIN
const verifyAdmin = async (req, res, next) => {
    const adminId = req.headers['admin-id'];
    if (!adminId) {
        return res.status(401).json({ status: 'error', message: 'Thiếu thông tin Admin (Header admin-id)!' });
    }
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('id', sql.Int, adminId)
            .query("SELECT * FROM NguoiDung WHERE Id = @id AND LOWER(TRIM(VaiTro)) = 'admin'");
        
        if (result.recordset.length === 0) {
            return res.status(403).json({ status: 'error', message: 'Bạn không có quyền truy cập Admin!' });
        }
        next();
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
};

// ==================== 1. TÀI KHOẢN (ĐĂNG NHẬP / ĐĂNG KÝ) ====================
app.post('/api/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        let pool = await sql.connect(dbConfig);
        
        // Lấy thêm cột TrangThai
        let result = await pool.request()
            .input('email', sql.NVarChar, email)
            .input('password', sql.NVarChar, password)
            .query('SELECT Id, HoTen, Email, SoDienThoai, VaiTro, TrangThai FROM NguoiDung WHERE Email = @email AND MatKhau = @password');

        if (result.recordset.length > 0) {
            let user = result.recordset[0];
            
            // Kiểm tra xem có bị khóa không
            if (user.TrangThai === 'BiKhoa') {
                return res.json({ status: 'error', message: 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ Admin!' });
            }
            
            res.json({ status: 'success', user: user });
        } else {
            res.json({ status: 'error', message: 'Email hoặc mật khẩu không chính xác!' });
        }
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/register', async (req, res) => {
    try {
        const { fullName, email, password, phone } = req.body;
        let pool = await sql.connect(dbConfig);

        let checkUser = await pool.request()
            .input('email', sql.NVarChar, email)
            .query('SELECT Id FROM NguoiDung WHERE Email = @email');

        if (checkUser.recordset.length > 0) {
            return res.json({ status: 'error', message: 'Email này đã được sử dụng!' });
        }

        await pool.request()
            .input('fullName', sql.NVarChar, fullName)
            .input('email', sql.NVarChar, email)
            .input('password', sql.NVarChar, password)
            .input('phone', sql.NVarChar, phone || '')
            .query("INSERT INTO NguoiDung (HoTen, Email, MatKhau, SoDienThoai, VaiTro) VALUES (@fullName, @email, @password, @phone, 'KhachHang')");

        res.json({ status: 'success', message: 'Đăng ký tài khoản thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 2. SẢN PHẨM & DANH MỤC ====================
app.get('/api/categories', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query('SELECT * FROM DanhMuc');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.get('/api/products', async (req, res) => {
    try {
        const { query, categoryId } = req.query;
        let pool = await sql.connect(dbConfig);
        let sqlQuery = 'SELECT * FROM SanPham WHERE 1=1';

        if (query) sqlQuery += ` AND TenSanPham LIKE N'%${query}%'`;
        if (categoryId) sqlQuery += ` AND DanhMucId = ${categoryId}`;

        sqlQuery += ' ORDER BY Id DESC';

        let result = await pool.request().query(sqlQuery);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.get('/api/products/:id', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let productRes = await pool.request()
            .input('id', sql.Int, req.params.id)
            .query('SELECT * FROM SanPham WHERE Id = @id');
        
        let variantRes = await pool.request()
            .input('id', sql.Int, req.params.id)
            .query('SELECT * FROM SanPhamBienThe WHERE SanPhamId = @id');

        res.json({
            product: productRes.recordset[0],
            variants: variantRes.recordset
        });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// ==================== 3. GIỎ HÀNG (CART) ====================
app.get('/api/cart/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('userId', sql.Int, req.params.userId)
            .query(`
                SELECT 
                    gh.Id, 
                    gh.SanPhamBienTheId, 
                    gh.SoLuong, 
                    bt.MauSac, 
                    bt.KichThuoc, 
                    sp.TenSanPham, 
                    sp.Gia, 
                    sp.HinhAnh, 
                    (sp.Gia * gh.SoLuong) AS ThanhTien
                FROM GioHang gh
                JOIN SanPhamBienThe bt ON gh.SanPhamBienTheId = bt.Id
                JOIN SanPham sp ON bt.SanPhamId = sp.Id
                WHERE gh.NguoiDungId = @userId
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.post('/api/cart', async (req, res) => {
    try {
        const { userId, variantId, quantity } = req.body;

        // === VALIDATE ===
        if (!userId || !variantId || !quantity) {
            return res.status(400).json({
                status: 'error',
                message: `Thiếu dữ liệu: userId=${userId}, variantId=${variantId}, quantity=${quantity}`
            });
        }
        if (parseInt(quantity, 10) < 1) {
            return res.status(400).json({ status: 'error', message: 'Số lượng phải >= 1' });
        }

        let pool = await sql.connect(dbConfig);

        // Kiểm tra biến thể tồn tại
        let checkVariant = await pool.request()
            .input('variantId', sql.Int, variantId)
            .query('SELECT Id, SoLuong FROM SanPhamBienThe WHERE Id = @variantId');

        if (checkVariant.recordset.length === 0) {
            return res.status(404).json({
                status: 'error',
                message: `Không tìm thấy biến thể Id=${variantId} trong SanPhamBienThe!`
            });
        }

        console.log(`✅ Thêm giỏ: userId=${userId}, variantId=${variantId}, qty=${quantity}`);

        await pool.request()
            .input('userId', sql.Int, userId)
            .input('variantId', sql.Int, variantId)
            .input('quantity', sql.Int, quantity)
            .query(`
                IF EXISTS (SELECT 1 FROM GioHang WHERE NguoiDungId = @userId AND SanPhamBienTheId = @variantId)
                    UPDATE GioHang SET SoLuong = SoLuong + @quantity
                    WHERE NguoiDungId = @userId AND SanPhamBienTheId = @variantId;
                ELSE
                    INSERT INTO GioHang (NguoiDungId, SanPhamBienTheId, SoLuong)
                    VALUES (@userId, @variantId, @quantity);
            `);

        res.json({ status: 'success', message: 'Đã thêm vào giỏ hàng!' });
    } catch (err) {
        console.error('❌ Lỗi POST /api/cart:', err);
        res.status(500).json({
            status: 'error',
            message: err.message,
            sqlNumber: err.number, // mã lỗi SQL để debug
        });
    }
});

app.put('/api/cart/:cartId', async (req, res) => {
    try {
        const { quantity } = req.body;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('cartId', sql.Int, req.params.cartId)
            .input('quantity', sql.Int, quantity)
            .query('UPDATE GioHang SET SoLuong = @quantity WHERE Id = @cartId');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.delete('/api/cart/:cartId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('cartId', sql.Int, req.params.cartId)
            .query('DELETE FROM GioHang WHERE Id = @cartId');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// ==================== 4. SẢN PHẨM YÊU THÍCH (FAVORITES) ====================
app.get('/api/favorites/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('userId', sql.Int, req.params.userId)
            .query(`
                SELECT sp.* 
                FROM YeuThich yt
                JOIN SanPham sp ON yt.SanPhamId = sp.Id
                WHERE yt.NguoiDungId = @userId
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.post('/api/favorites/toggle', async (req, res) => {
    try {
        const { userId, productId } = req.body;
        let pool = await sql.connect(dbConfig);
        let check = await pool.request()
            .input('userId', sql.Int, userId)
            .input('productId', sql.Int, productId)
            .query('SELECT * FROM YeuThich WHERE NguoiDungId = @userId AND SanPhamId = @productId');

        if (check.recordset.length > 0) {
            await pool.request()
                .input('userId', sql.Int, userId)
                .input('productId', sql.Int, productId)
                .query('DELETE FROM YeuThich WHERE NguoiDungId = @userId AND SanPhamId = @productId');
            res.json({ status: 'success', action: 'removed', message: 'Đã xóa khỏi Yêu thích' });
        } else {
            await pool.request()
                .input('userId', sql.Int, userId)
                .input('productId', sql.Int, productId)
                .query('INSERT INTO YeuThich (NguoiDungId, SanPhamId) VALUES (@userId, @productId)');
            res.json({ status: 'success', action: 'added', message: 'Đã thêm vào Yêu thích' });
        }
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 5. MÃ KHUYẾN MÃI (PROMOTIONS) ====================
app.get('/api/admin/promotions', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`
            SELECT Id, MaGiamGia, PhanTramGiam, ISNULL(SoLuong, 0) AS SoLuong, ISNULL(DaSuDung, 0) AS DaSuDung, MoTa 
            FROM KhuyenMai 
            ORDER BY Id DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// 1. API Tạo khuyến mãi (Tự cộng 5 phút)
app.post('/api/admin/promotions', verifyAdmin, async (req, res) => {
    try {
        const { code, percent, limit, description } = req.body;
        const percentNum = parseInt(percent, 10);
        
        if (isNaN(percentNum) || percentNum < 1 || percentNum > 100) {
            return res.status(400).json({ status: 'error', message: 'Phần trăm giảm phải từ 1-100!' });
        }
        
        let pool = await sql.connect(dbConfig);
        
        // Tự động cộng thêm 5 phút kể từ lúc tạo để test
        await pool.request()
            .input('code', sql.NVarChar, code)
            .input('percent', sql.Int, percentNum)
            .input('limit', sql.Int, limit || 50)
            .input('description', sql.NVarChar, description || '')
            .query(`
                INSERT INTO KhuyenMai (MaGiamGia, PhanTramGiam, SoLuong, DaSuDung, MoTa, NgayHetHan)
                VALUES (@code, @percent, @limit, 0, @description, DATEADD(MINUTE, 5, GETDATE()))
            `);
            
        res.json({ status: 'success', message: 'Tạo mã khuyến mãi thành công (Hết hạn sau 5 phút)!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// 2. API Áp dụng khuyến mãi (Kiểm tra thời gian thực)
app.post('/api/promotions/apply', async (req, res) => {
    try {
        const { code, totalAmount } = req.body;
        let pool = await sql.connect(dbConfig);
        
        let result = await pool.request()
            .input('code', sql.NVarChar, code)
            .query('SELECT *, CASE WHEN NgayHetHan IS NOT NULL AND GETDATE() > NgayHetHan THEN 1 ELSE 0 END AS IsExpired FROM KhuyenMai WHERE MaGiamGia = @code');

        if (result.recordset.length === 0) {
            return res.json({ status: 'error', message: 'Mã khuyến mãi không tồn tại!' });
        }

        let promo = result.recordset[0];

        // Kiểm tra hết hạn theo thời gian (5 phút)
        if (promo.IsExpired === 1) {
            return res.json({ status: 'error', message: 'Mã khuyến mãi đã hết hạn sử dụng!' });
        }

        // Kiểm tra số lượng
        let soLuong = promo.SoLuong || 0;
        let daSuDung = promo.DaSuDung || 0;
        if (daSuDung >= soLuong) {
            return res.json({ status: 'error', message: 'Mã khuyến mãi đã hết lượt sử dụng!' });
        }

        let discountPercent = promo.PhanTramGiam || 0;
        let discountAmount = (totalAmount * discountPercent) / 100;

        res.json({
            status: 'success',
            message: `Áp dụng thành công mã -${discountPercent}%`,
            discountAmount: discountAmount,
            discountPercent: discountPercent
        });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 6. CHỨC NĂNG ĐƠN HÀNG (MUA NGAY & GIỎ HÀNG) ====================
app.get('/api/orders/user/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let ordersRes = await pool.request()
            .input('userId', sql.Int, req.params.userId)
            .query('SELECT * FROM DonHang WHERE NguoiDungId = @userId ORDER BY Id DESC');

        let orders = ordersRes.recordset;
        for (let order of orders) {
            let detailRes = await pool.request()
    .input('orderId', sql.Int, order.Id)
    .query(`
        SELECT ct.*, bt.SanPhamId, sp.TenSanPham, sp.HinhAnh, bt.MauSac, bt.KichThuoc 
        FROM ChiTietDonHang ct
        JOIN SanPhamBienThe bt ON ct.SanPhamBienTheId = bt.Id
        JOIN SanPham sp ON bt.SanPhamId = sp.Id
        WHERE ct.DonHangId = @orderId
    `);
            order.ChiTiet = detailRes.recordset;
        }

        res.json(orders);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.post('/api/orders', async (req, res) => {
    try {
        const { userId, address, paymentMethod, totalAmount, promoCode, items } = req.body;
        let pool = await sql.connect(dbConfig);

        let orderItems = [];

        if (items && Array.isArray(items) && items.length > 0) {
            orderItems = items;
        } else {
            let cartItems = await pool.request()
                .input('userId', sql.Int, userId)
                .query('SELECT gh.SanPhamBienTheId, gh.SoLuong, sp.Gia FROM GioHang gh JOIN SanPhamBienThe bt ON gh.SanPhamBienTheId = bt.Id JOIN SanPham sp ON bt.SanPhamId = sp.Id WHERE gh.NguoiDungId = @userId');
            orderItems = cartItems.recordset;
        }

        if (orderItems.length === 0) {
            return res.status(400).json({ status: 'error', message: 'Không có sản phẩm nào để đặt hàng!' });
        }

        // Tạo Đơn hàng mới
        let orderRes = await pool.request()
            .input('userId', sql.Int, userId)
            .input('address', sql.NVarChar, address)
            .input('paymentMethod', sql.NVarChar, paymentMethod)
            .input('totalAmount', sql.Decimal(18, 2), totalAmount)
            .query(`
                INSERT INTO DonHang (NguoiDungId, DiaChiGiao, PhuongThucTT, TongTien, TrangThai, NgayTao)
                OUTPUT INSERTED.Id
                VALUES (@userId, @address, @paymentMethod, @totalAmount, N'ChoXacNhan', GETDATE())
            `);

        let orderId = orderRes.recordset[0].Id;

        // Thêm chi tiết
        for (let item of orderItems) {
            // Chỉ lấy đúng SanPhamBienTheId hoặc Id (không lấy nhầm id của giỏ hàng)
            let variantId = item.SanPhamBienTheId || item.Id || item.variantId;
            let qty = item.SoLuong || item.quantity || 1;
            let price = item.Gia || item.price || 0;

            // Kiểm tra xem biến thể này có thực sự tồn tại không trước khi chèn
            let checkExist = await pool.request()
                .input('variantId', sql.Int, variantId)
                .query('SELECT Id FROM SanPhamBienThe WHERE Id = @variantId');

            if (checkExist.recordset.length === 0) {
                console.log(`BỎ QUA: Biến thể ID=${variantId} không có trong kho!`);
                continue; // Bỏ qua sản phẩm lỗi này, không chèn vào chi tiết đơn hàng
            }

            console.log(`[ĐÃ CHÈN] Đơn: ${orderId} | Biến thể ID: ${variantId} | SL: ${qty}`);
            
            await pool.request()
                .input('orderId', sql.Int, orderId)
                .input('variantId', sql.Int, variantId)
                .input('quantity', sql.Int, qty)
                .input('price', sql.Decimal(18, 2), price)
                .query('INSERT INTO ChiTietDonHang (DonHangId, SanPhamBienTheId, SoLuong, DonGia) VALUES (@orderId, @variantId, @quantity, @price)');

            await pool.request()
.input('variantId', sql.Int, variantId)
                .input('quantity', sql.Int, qty)
                .query('UPDATE SanPhamBienThe SET SoLuong = CASE WHEN SoLuong >= @quantity THEN SoLuong - @quantity ELSE 0 END WHERE Id = @variantId');
        }

        if (promoCode) {
            await pool.request()
                .input('code', sql.NVarChar, promoCode)
                .query('UPDATE KhuyenMai SET DaSuDung = ISNULL(DaSuDung, 0) + 1 WHERE MaGiamGia = @code');
        }

        // Dọn dẹp giỏ hàng
        await pool.request().input('userId', sql.Int, userId).query('DELETE FROM GioHang WHERE NguoiDungId = @userId');

        res.json({ status: 'success', message: 'Đặt hàng thành công!', orderId: orderId });
    } catch (err) {
        console.error("Lỗi đặt hàng:", err.message);
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/orders/:orderId/cancel', async (req, res) => {
    try {
        const { userId } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        let orderCheck = await pool.request()
            .input('orderId', sql.Int, orderId)
            .input('userId', sql.Int, userId)
            .query('SELECT * FROM DonHang WHERE Id = @orderId AND NguoiDungId = @userId');

        if (orderCheck.recordset.length === 0) {
            return res.json({ status: 'error', message: 'Không tìm thấy đơn hàng!' });
        }

        let order = orderCheck.recordset[0];
        if (order.TrangThai === 'ChoXacNhan') {
            let details = await pool.request()
                .input('orderId', sql.Int, orderId)
                .query('SELECT * FROM ChiTietDonHang WHERE DonHangId = @orderId');

            for (let item of details.recordset) {
                await pool.request()
                    .input('variantId', sql.Int, item.SanPhamBienTheId)
                    .input('quantity', sql.Int, item.SoLuong)
                    .query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @quantity WHERE Id = @variantId');
            }

            await pool.request().input('orderId', sql.Int, orderId).query('DELETE FROM ChiTietDonHang WHERE DonHangId = @orderId');
            await pool.request().input('orderId', sql.Int, orderId).query('DELETE FROM DonHang WHERE Id = @orderId');

            return res.json({ status: 'success', message: 'Đã hủy đơn hàng và hoàn lại kho!' });
        } else {
            await pool.request()
                .input('orderId', sql.Int, orderId)
                .query("UPDATE DonHang SET TrangThai = N'DaHuy' WHERE Id = @orderId");
            return res.json({ status: 'success', message: 'Đã chuyển đơn hàng sang trạng thái Đã hủy!' });
        }
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 7. API QUẢN TRỊ ADMIN ====================
app.get('/api/admin/orders', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`
            SELECT dh.*, nd.HoTen, nd.Email 
            FROM DonHang dh 
            JOIN NguoiDung nd ON dh.NguoiDungId = nd.Id 
            ORDER BY dh.Id DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.put('/api/admin/orders/:id/status', verifyAdmin, async (req, res) => {
    try {
        const { status } = req.body;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('id', sql.Int, req.params.id)
            .input('status', sql.NVarChar, status)
            .query('UPDATE DonHang SET TrangThai = @status WHERE Id = @id');
        res.json({ status: 'success', message: 'Cập nhật trạng thái thành công!' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.get('/api/admin/customers', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query("SELECT Id, HoTen, Email, SoDienThoai, VaiTro FROM NguoiDung WHERE LOWER(TRIM(VaiTro)) != 'admin'");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// XÓA TÀI KHOẢN KHÁCH HÀNG (chỉ admin)
app.delete('/api/admin/customers/:id', verifyAdmin, async (req, res) => {
    try {
        const customerId = parseInt(req.params.id, 10);
        if (isNaN(customerId)) {
            return res.status(400).json({ status: 'error', message: 'ID khách hàng không hợp lệ!' });
        }

        let pool = await sql.connect(dbConfig);

        // 1. Kiểm tra tồn tại + không cho xóa Admin
        let checkUser = await pool.request()
            .input('id', sql.Int, customerId)
            .query("SELECT Id, VaiTro FROM NguoiDung WHERE Id = @id");

        if (checkUser.recordset.length === 0) {
            return res.status(404).json({ status: 'error', message: 'Không tìm thấy khách hàng!' });
        }

        let targetUser = checkUser.recordset[0];
        if ((targetUser.VaiTro || '').trim().toLowerCase() === 'admin') {
            return res.status(403).json({ status: 'error', message: 'Không thể xóa tài khoản Admin!' });
        }

        // 2. Dọn dẹp dữ liệu liên quan (theo thứ tự khóa ngoại)
        // 2.1. ChiTietDonHang của các đơn hàng thuộc user này
        await pool.request()
            .input('id', sql.Int, customerId)
            .query(`
                DELETE ct
                FROM ChiTietDonHang ct
                JOIN DonHang dh ON ct.DonHangId = dh.Id
                WHERE dh.NguoiDungId = @id
            `);

        // 2.2. Đơn hàng
        await pool.request()
            .input('id', sql.Int, customerId)
            .query('DELETE FROM DonHang WHERE NguoiDungId = @id');

        // 2.3. Giỏ hàng
        await pool.request()
            .input('id', sql.Int, customerId)
            .query('DELETE FROM GioHang WHERE NguoiDungId = @id');

        // 2.4. Yêu thích
        await pool.request()
            .input('id', sql.Int, customerId)
            .query('DELETE FROM YeuThich WHERE NguoiDungId = @id');

        // 2.5. Cuối cùng: xóa tài khoản
        await pool.request()
            .input('id', sql.Int, customerId)
            .query('DELETE FROM NguoiDung WHERE Id = @id');

        res.json({ status: 'success', message: 'Đã xóa tài khoản khách hàng thành công!' });
    } catch (err) {
        console.error('Lỗi xóa khách hàng:', err.message);
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// API KHÓA / MỞ KHÓA TÀI KHOẢN KHÁCH HÀNG
app.put('/api/admin/customers/:id/toggle-status', verifyAdmin, async (req, res) => {
    try {
        const customerId = parseInt(req.params.id, 10);
        let pool = await sql.connect(dbConfig);

        // Lấy trạng thái hiện tại
        let userRes = await pool.request()
            .input('id', sql.Int, customerId)
            .query('SELECT TrangThai FROM NguoiDung WHERE Id = @id');

        if (userRes.recordset.length === 0) {
            return res.status(404).json({ status: 'error', message: 'Không tìm thấy khách hàng!' });
        }

        // Đảo ngược trạng thái
        let currentStatus = userRes.recordset[0].TrangThai;
        let newStatus = currentStatus === 'BiKhoa' ? 'HoatDong' : 'BiKhoa';

        await pool.request()
            .input('id', sql.Int, customerId)
            .input('status', sql.NVarChar, newStatus)
            .query('UPDATE NguoiDung SET TrangThai = @status WHERE Id = @id');

        res.json({ status: 'success', message: `Đã ${newStatus === 'BiKhoa' ? 'khóa' : 'mở khóa'} tài khoản!` });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/admin/products', verifyAdmin, async (req, res) => {
    try {
        const { name, categoryId, price, image, description } = req.body;
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('name', sql.NVarChar, name)
            .input('categoryId', sql.Int, categoryId)
            .input('price', sql.Decimal(18, 2), price)
            .input('image', sql.NVarChar, image)
            .input('description', sql.NVarChar, description)
            .query(`
                INSERT INTO SanPham (TenSanPham, DanhMucId, Gia, HinhAnh, MoTa)
                OUTPUT INSERTED.Id
                VALUES (@name, @categoryId, @price, @image, @description)
            `);
        res.json({ status: 'success', message: 'Thêm sản phẩm thành công!', productId: result.recordset[0].Id });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.delete('/api/admin/products/:id', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let productId = req.params.id;
        
        await pool.request().input('id', sql.Int, productId).query('DELETE FROM SanPhamBienThe WHERE SanPhamId = @id');
        await pool.request().input('id', sql.Int, productId).query('DELETE FROM YeuThich WHERE SanPhamId = @id');
        await pool.request().input('id', sql.Int, productId).query('DELETE FROM SanPham WHERE Id = @id');
        
        res.json({ status: 'success', message: 'Xóa hoàn toàn sản phẩm thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/admin/inventory/import', verifyAdmin, async (req, res) => {
    try {
        const { sanPhamId, mauSac, kichThuoc, soLuongNhap } = req.body;
        let pool = await sql.connect(dbConfig);

        let checkVariant = await pool.request()
            .input('sanPhamId', sql.Int, sanPhamId)
            .input('mauSac', sql.NVarChar, mauSac)
            .input('kichThuoc', sql.NVarChar, kichThuoc)
            .query('SELECT Id FROM SanPhamBienThe WHERE SanPhamId = @sanPhamId AND MauSac = @mauSac AND KichThuoc = @kichThuoc');

        if (checkVariant.recordset.length > 0) {
            let id = checkVariant.recordset[0].Id;
            await pool.request()
                .input('id', sql.Int, id)
                .input('soLuong', sql.Int, soLuongNhap)
                .query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @soLuong WHERE Id = @id');
        } else {
            await pool.request()
                .input('sanPhamId', sql.Int, sanPhamId)
                .input('mauSac', sql.NVarChar, mauSac)
                .input('kichThuoc', sql.NVarChar, kichThuoc)
                .input('soLuong', sql.Int, soLuongNhap)
                .query('INSERT INTO SanPhamBienThe (SanPhamId, MauSac, KichThuoc, SoLuong) VALUES (@sanPhamId, @mauSac, @kichThuoc, @soLuong)');
        }

        res.json({ status: 'success', message: 'Nhập kho thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 10. ROBOT TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI (TEST 30s) ====================
setInterval(async () => {
    try {
        let pool = await sql.connect(dbConfig);

        // 1. Nếu có đơn "Chờ xác nhận" -> Chuyển sang "Đã xác nhận"
        let check1 = await pool.request().query(`
            UPDATE DonHang SET TrangThai = N'DaXacNhan' 
            OUTPUT INSERTED.Id 
            WHERE Id IN (SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'ChoXacNhan')
        `);

        // Nếu đã xử lý đơn ở bước 1, thì bỏ qua các bước sau trong lượt này
        if (check1.recordset.length > 0) {
            console.log(`🤖 [ROBOT] Đã duyệt đơn #${check1.recordset[0].Id} -> Đã xác nhận`);
            return; 
        }

        // 2. Nếu không có đơn chờ duyệt, chuyển đơn "Đã xác nhận" -> "Đang giao"
        let check2 = await pool.request().query(`
            UPDATE DonHang SET TrangThai = N'DangGiao' 
            OUTPUT INSERTED.Id 
            WHERE Id IN (SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'DaXacNhan')
        `);

        if (check2.recordset.length > 0) {
            console.log(`🤖 [ROBOT] Đã giao đơn #${check2.recordset[0].Id} cho shipper`);
            return;
        }

        // 3. Nếu không có đơn đã xác nhận, xử lý đơn "Đang giao" -> 50% Đã giao, 50% Đã hủy
        // 3. Nếu không có đơn đã xác nhận, xử lý đơn "Đang giao" -> 50% Đã giao, 50% Đã hủy
        let deliveringOrders = await pool.request().query(`
            SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'DangGiao'
        `);

        if (deliveringOrders.recordset.length > 0) {
            let orderId = deliveringOrders.recordset[0].Id;
            let isSuccess = Math.random() < 0.5; // Tung đồng xu 50/50
            let newStatus = isSuccess ? 'DaGiao' : 'DaHuy';

            await pool.request()
                .input('id', sql.Int, orderId)
                .input('status', sql.NVarChar, newStatus)
                .query('UPDATE DonHang SET TrangThai = @status, NgayGiaoHang = GETDATE() WHERE Id = @id'); // <-- Thêm NgayGiaoHang = GETDATE()

            if (!isSuccess) {
                // Nếu hủy đơn, hoàn lại số lượng vào kho
                let details = await pool.request()
                    .input('orderId', sql.Int, orderId)
                    .query('SELECT SanPhamBienTheId, SoLuong FROM ChiTietDonHang WHERE DonHangId = @orderId');
                
                for (let item of details.recordset) {
                    await pool.request()
                        .input('variantId', sql.Int, item.SanPhamBienTheId)
                        .input('qty', sql.Int, item.SoLuong)
                        .query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @qty WHERE Id = @variantId');
                }
            }
            console.log(`🤖 [ROBOT] Đơn #${orderId} đã ${isSuccess ? 'GIAO THÀNH CÔNG' : 'BỊ KHÁCH HỦY'}`);
        }
    } catch (err) {
        console.error('Lỗi Robot tự động:', err.message);
    }
}, 30000); // 30000 ms = 30 giây
// ==================== 12. API CHAT TRỰC TUYẾN ====================

// Lấy tin nhắn
app.get('/api/chat/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('userId', sql.Int, req.params.userId)
            .query('SELECT * FROM TinNhanChat WHERE NguoiDungId = @userId ORDER BY ThoiGian ASC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// Gửi tin nhắn
app.post('/api/chat', async (req, res) => {
    try {
        const { userId, sender, message } = req.body;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('userId', sql.Int, userId)
            .input('sender', sql.NVarChar, sender)
            .input('message', sql.NVarChar, message)
            .query('INSERT INTO TinNhanChat (NguoiDungId, NguoiGui, NoiDung) VALUES (@userId, @sender, @message)');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// KHỞI CHẠY SERVER
const PORT = 3000;

// ==================== 8. API THỐNG KÊ DOANH THU (ADMIN) ====================
app.get('/api/admin/statistics', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        
        // 1. Tổng doanh thu (Chỉ tính các đơn không bị hủy)
        let revenueRes = await pool.request().query(`
            SELECT ISNULL(SUM(TongTien), 0) AS TotalRevenue 
            FROM DonHang 
            WHERE TrangThai != 'DaHuy'
        `);
        
        // 2. Tổng số đơn hàng
        let ordersRes = await pool.request().query('SELECT COUNT(Id) AS TotalOrders FROM DonHang');
        
        // 3. Tổng số khách hàng
        let customersRes = await pool.request().query("SELECT COUNT(Id) AS TotalCustomers FROM NguoiDung WHERE VaiTro = 'KhachHang'");
        
        // 4. Doanh thu 7 ngày gần nhất (Dùng cho biểu đồ)
        let chartRes = await pool.request().query(`
            SELECT 
                FORMAT(NgayTao, 'dd/MM') AS Ngay, 
                SUM(TongTien) AS DoanhThu
            FROM DonHang 
            WHERE TrangThai != 'DaHuy' AND NgayTao >= DATEADD(day, -6, GETDATE())
            GROUP BY FORMAT(NgayTao, 'dd/MM'), CAST(NgayTao AS DATE)
            ORDER BY CAST(NgayTao AS DATE) ASC
        `);

        res.json({
            status: 'success',
            data: {
                totalRevenue: revenueRes.recordset[0].TotalRevenue,
                totalOrders: ordersRes.recordset[0].TotalOrders,
                totalCustomers: customersRes.recordset[0].TotalCustomers,
                chartData: chartRes.recordset
            }
        });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 9. API LẤY DANH SÁCH TỒN KHO CHI TIẾT ====================
app.get('/api/admin/inventory', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`
            SELECT 
                bt.Id AS BienTheId,
                sp.TenSanPham,
                sp.HinhAnh,
                bt.MauSac,
                bt.KichThuoc,
                bt.SoLuong
            FROM SanPhamBienThe bt
            JOIN SanPham sp ON bt.SanPhamId = sp.Id
            ORDER BY bt.SoLuong ASC, sp.TenSanPham ASC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// ==================== 11. API ĐÁNH GIÁ SẢN PHẨM ====================

// 1. Lấy danh sách đánh giá của 1 sản phẩm
app.get('/api/reviews/:productId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('productId', sql.Int, req.params.productId)
            .query(`
                SELECT dg.Id, dg.SoSao, dg.BinhLuan, dg.NgayDanhGia, nd.HoTen
                FROM DanhGia dg
                JOIN NguoiDung nd ON dg.NguoiDungId = nd.Id
                WHERE dg.SanPhamId = @productId
                ORDER BY dg.NgayDanhGia DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// 2. Lấy danh sách các sản phẩm đã đánh giá của 1 khách hàng
app.get('/api/reviews/user/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('userId', sql.Int, req.params.userId)
            .query(`
                SELECT dg.Id, dg.SoSao, dg.BinhLuan, dg.NgayDanhGia, sp.TenSanPham, sp.HinhAnh, sp.Id AS SanPhamId
                FROM DanhGia dg
                JOIN SanPham sp ON dg.SanPhamId = sp.Id
                WHERE dg.NguoiDungId = @userId
                ORDER BY dg.NgayDanhGia DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// 3. Gửi đánh giá mới (Chỉ cho phép nếu đã mua hàng và chưa đánh giá)
app.post('/api/reviews', async (req, res) => {
    try {
        const { userId, productId, soSao, binhLuan } = req.body;
        let pool = await sql.connect(dbConfig);

        // Kiểm tra xem khách đã mua sản phẩm này chưa (Đơn phải có trạng thái DaGiao)
        let checkBought = await pool.request()
            .input('userId', sql.Int, userId)
            .input('productId', sql.Int, productId)
            .query(`
                SELECT dh.Id 
                FROM DonHang dh
                JOIN ChiTietDonHang ct ON dh.Id = ct.DonHangId
                JOIN SanPhamBienThe bt ON ct.SanPhamBienTheId = bt.Id
                WHERE dh.NguoiDungId = @userId AND bt.SanPhamId = @productId AND dh.TrangThai = N'DaGiao'
            `);

        if (checkBought.recordset.length === 0) {
            return res.status(400).json({ status: 'error', message: 'Bạn phải mua và nhận hàng thành công mới được đánh giá!' });
        }

        // Kiểm tra xem đã đánh giá chưa (1 người 1 sản phẩm chỉ 1 đánh giá)
        let checkReviewed = await pool.request()
            .input('userId', sql.Int, userId)
            .input('productId', sql.Int, productId)
            .query('SELECT Id FROM DanhGia WHERE NguoiDungId = @userId AND SanPhamId = @productId');
if (checkReviewed.recordset.length > 0) {
            return res.status(400).json({ status: 'error', message: 'Bạn đã đánh giá sản phẩm này rồi!' });
        }

        await pool.request()
            .input('userId', sql.Int, userId)
            .input('productId', sql.Int, productId)
            .input('soSao', sql.Int, soSao)
            .input('binhLuan', sql.NVarChar, binhLuan)
            .query('INSERT INTO DanhGia (NguoiDungId, SanPhamId, SoSao, BinhLuan) VALUES (@userId, @productId, @soSao, @binhLuan)');

        res.json({ status: 'success', message: 'Cảm ơn bạn đã đánh giá sản phẩm!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// API KHÁCH YÊU CẦU HOÀN ĐƠN
app.put('/api/orders/:orderId/return', async (req, res) => {
    try {
        const { userId, reason } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        // Kiểm tra đơn hàng hợp lệ
        let check = await pool.request()
            .input('id', sql.Int, orderId)
            .input('userId', sql.Int, userId)
            .query("SELECT * FROM DonHang WHERE Id = @id AND NguoiDungId = @userId AND TrangThai = N'DaGiao'");

        if (check.recordset.length === 0) {
            return res.status(400).json({ status: 'error', message: 'Đơn hàng không hợp lệ hoặc chưa giao thành công!' });
        }

        // Cập nhật yêu cầu hoàn
        await pool.request()
            .input('id', sql.Int, orderId)
            .input('reason', sql.NVarChar, reason)
            .query("UPDATE DonHang SET TrangThaiHoan = N'ChoDuyet', LyDoHoan = @reason WHERE Id = @id");

        res.json({ status: 'success', message: 'Đã gửi yêu cầu hoàn đơn. Vui lòng chờ Admin duyệt!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// API ADMIN DUYỆT HOÀN ĐƠN
app.put('/api/admin/orders/:orderId/approve-return', verifyAdmin, async (req, res) => {
    try {
        const { isApproved } = req.body; // true = đồng ý, false = từ chối
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        if (isApproved) {
            // 1. Nếu đồng ý: Cộng lại số lượng vào kho
            let details = await pool.request()
                .input('orderId', sql.Int, orderId)
                .query('SELECT SanPhamBienTheId, SoLuong FROM ChiTietDonHang WHERE DonHangId = @orderId');

            for (let item of details.recordset) {
                await pool.request()
                    .input('variantId', sql.Int, item.SanPhamBienTheId)
                    .input('qty', sql.Int, item.SoLuong)
                    .query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @qty WHERE Id = @variantId');
            }

            // 2. Cập nhật đơn thành Đã Hủy và Trạng thái hoàn là Đã duyệt
            await pool.request()
                .input('id', sql.Int, orderId)
                .query("UPDATE DonHang SET TrangThai = N'DaHuy', TrangThaiHoan = N'DaDuyet' WHERE Id = @id");
        } else {
            // Nếu từ chối: Trả lại trạng thái không có yêu cầu hoàn
            await pool.request()
                .input('id', sql.Int, orderId)
                .query("UPDATE DonHang SET TrangThaiHoan = N'TuChoi' WHERE Id = @id");
        }

        res.json({ status: 'success', message: isApproved ? 'Đã duyệt hoàn đơn và cộng lại kho!' : 'Đã từ chối yêu cầu hoàn!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// API KHÁCH YÊU CẦU HOÀN ĐƠN (Giới hạn 7 ngày)
app.put('/api/orders/:orderId/return', async (req, res) => {
    try {
        const { userId, reason } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        let check = await pool.request()
            .input('id', sql.Int, orderId)
            .input('userId', sql.Int, userId)
            .query("SELECT *, DATEDIFF(DAY, NgayGiaoHang, GETDATE()) AS SoNgayDaNhan FROM DonHang WHERE Id = @id AND NguoiDungId = @userId AND TrangThai = N'DaGiao'");

        if (check.recordset.length === 0) {
            return res.status(400).json({ status: 'error', message: 'Đơn hàng không hợp lệ hoặc chưa giao thành công!' });
        }

        let order = check.recordset[0];
        // Kiểm tra quá 7 ngày
        if (order.SoNgayDaNhan > 7) {
            return res.status(400).json({ status: 'error', message: 'Đã quá hạn 7 ngày đổi trả kể từ ngày nhận hàng!' });
        }

        await pool.request()
            .input('id', sql.Int, orderId)
            .input('reason', sql.NVarChar, reason)
            .query("UPDATE DonHang SET TrangThaiHoan = N'ChoDuyet', LyDoHoan = @reason WHERE Id = @id");

        res.json({ status: 'success', message: 'Đã gửi yêu cầu hoàn đơn. Vui lòng chờ Admin duyệt!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
// API ADMIN DUYỆT HOÀN ĐƠN
app.put('/api/admin/orders/:orderId/approve-return', verifyAdmin, async (req, res) => {
    try {
        const { isApproved } = req.body; // true = đồng ý, false = từ chối
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        if (isApproved) {
            // 1. Nếu đồng ý: Cộng lại số lượng vào kho
            let details = await pool.request()
                .input('orderId', sql.Int, orderId)
                .query('SELECT SanPhamBienTheId, SoLuong FROM ChiTietDonHang WHERE DonHangId = @orderId');

            for (let item of details.recordset) {
                await pool.request()
                    .input('variantId', sql.Int, item.SanPhamBienTheId)
                    .input('qty', sql.Int, item.SoLuong)
                    .query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @qty WHERE Id = @variantId');
            }

            // 2. Cập nhật đơn thành Đã Hủy và Trạng thái hoàn là Đã duyệt
            await pool.request()
                .input('id', sql.Int, orderId)
                .query("UPDATE DonHang SET TrangThai = N'DaHuy', TrangThaiHoan = N'DaDuyet' WHERE Id = @id");
        } else {
            // Nếu từ chối: Trả lại trạng thái không có yêu cầu hoàn
            await pool.request()
                .input('id', sql.Int, orderId)
                .query("UPDATE DonHang SET TrangThaiHoan = N'TuChoi' WHERE Id = @id");
        }

        res.json({ status: 'success', message: isApproved ? 'Đã duyệt hoàn đơn và cộng lại kho!' : 'Đã từ chối yêu cầu hoàn!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});
app.listen(PORT, () => console.log(`🚀 Backend Server API đang chạy tại http://localhost:${PORT}`));