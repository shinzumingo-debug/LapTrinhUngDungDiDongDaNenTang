const express = require('express');
const cors = require('cors');
const sql = require('mssql');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

// CẤU HÌNH GỬI MAIL
const mailTransporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: 'shinzumingo@gmail.com',
        pass: 'bgicjrjgbtscxjfz' 
    }
});

let otpStorage = {}; 

// CẤU HÌNH KẾT NỐI DATABASE
const dbConfig = {
    user: 'sa',
    password: '123456', 
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

// ==================== 1. TÀI KHOẢN & OTP ====================
app.post('/api/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        let pool = await sql.connect(dbConfig);
        let result = await pool.request()
            .input('email', sql.NVarChar, email)
            .input('password', sql.NVarChar, password)
            .query('SELECT Id, HoTen, Email, SoDienThoai, VaiTro, TrangThai FROM NguoiDung WHERE Email = @email AND MatKhau = @password');

        if (result.recordset.length > 0) {
            let user = result.recordset[0];
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

app.post('/api/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        let pool = await sql.connect(dbConfig);
        let checkEmail = await pool.request()
            .input('email', sql.NVarChar, email)
            .query('SELECT Id FROM NguoiDung WHERE Email = @email');

        if (checkEmail.recordset.length === 0) {
            return res.json({ status: 'error', message: 'Email này chưa được đăng ký!' });
        }

        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        otpStorage[email] = { type: 'forgot', code: otpCode, expiresAt: Date.now() + 5 * 60 * 1000 };

        const mailOptions = {
            from: '"SHAVIK SHOP" <shinzumingo@gmail.com>',
            to: email,
            subject: 'Mã xác nhận khôi phục mật khẩu - SHAVIK SHOP',
            html: `<h2>Mã OTP của bạn là: <b>${otpCode}</b></h2>`
        };

        await mailTransporter.sendMail(mailOptions);
        res.json({ status: 'success', message: 'Mã OTP đã được gửi đến Gmail của bạn!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: 'Lỗi gửi Email!' });
    }
});

app.post('/api/reset-password-otp', async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;
        let savedOtp = otpStorage[email];

        if (!savedOtp || savedOtp.type !== 'forgot') return res.json({ status: 'error', message: 'Vui lòng yêu cầu mã OTP trước!' });
        if (Date.now() > savedOtp.expiresAt) return res.json({ status: 'error', message: 'Mã OTP đã hết hạn!' });
        if (savedOtp.code !== otp) return res.json({ status: 'error', message: 'Mã OTP không chính xác!' });

        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('email', sql.NVarChar, email)
            .input('newPassword', sql.NVarChar, newPassword)
            .query('UPDATE NguoiDung SET MatKhau = @newPassword WHERE Email = @email');

        delete otpStorage[email];
        res.json({ status: 'success', message: 'Đổi mật khẩu thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/register-request-otp', async (req, res) => {
    try {
        const { fullName, email, password, phone } = req.body;
        let pool = await sql.connect(dbConfig);

        let checkUser = await pool.request().input('email', sql.NVarChar, email).query('SELECT Id FROM NguoiDung WHERE Email = @email');
        if (checkUser.recordset.length > 0) return res.json({ status: 'error', message: 'Email này đã được sử dụng!' });

        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        otpStorage[email] = { type: 'register', code: otpCode, data: { fullName, email, password, phone }, expiresAt: Date.now() + 5 * 60 * 1000 };

        const mailOptions = {
            from: '"SHAVIK SHOP" <shinzumingo@gmail.com>',
            to: email,
            subject: 'Mã xác nhận đăng ký tài khoản - SHAVIK SHOP',
            html: `<h2>Mã OTP đăng ký của bạn là: <b>${otpCode}</b></h2>`
        };

        await mailTransporter.sendMail(mailOptions);
        res.json({ status: 'success', message: 'Mã OTP đã được gửi!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: 'Lỗi gửi Email!' });
    }
});

app.post('/api/register-verify-otp', async (req, res) => {
    try {
        const { email, otp } = req.body;
        let savedOtp = otpStorage[email];

        if (!savedOtp || savedOtp.type !== 'register') return res.json({ status: 'error', message: 'Vui lòng yêu cầu mã OTP!' });
        if (Date.now() > savedOtp.expiresAt) return res.json({ status: 'error', message: 'Mã OTP đã hết hạn!' });
        if (savedOtp.code !== otp) return res.json({ status: 'error', message: 'Mã OTP không chính xác!' });

        const { fullName, password, phone } = savedOtp.data;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('fullName', sql.NVarChar, fullName)
            .input('email', sql.NVarChar, email)
            .input('password', sql.NVarChar, password)
            .input('phone', sql.NVarChar, phone || '')
            .query("INSERT INTO NguoiDung (HoTen, Email, MatKhau, SoDienThoai, VaiTro) VALUES (@fullName, @email, @password, @phone, 'KhachHang')");

        delete otpStorage[email];
        res.json({ status: 'success', message: 'Đăng ký thành công!' });
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
        const { query, categoryId, sortBy } = req.query;
        let pool = await sql.connect(dbConfig);
        
        // SỬA LẠI HOÀN TOÀN CÂU QUERY ĐỂ KHÔNG BỊ LỖI GROUP BY
        let sqlQuery = `
            SELECT sp.*, 
            ISNULL((SELECT AVG(dg.SoSao) FROM DanhGia dg WHERE dg.SanPhamId = sp.Id), 0) AS DiemDanhGia, 
            (SELECT COUNT(dg.Id) FROM DanhGia dg WHERE dg.SanPhamId = sp.Id) AS SoLuongDanhGia
            FROM SanPham sp
            WHERE 1=1
        `;

        if (query) sqlQuery += ` AND sp.TenSanPham LIKE N'%${query}%'`;
        if (categoryId) sqlQuery += ` AND sp.DanhMucId = ${categoryId}`;

        switch (sortBy) {
            case 'az': sqlQuery += ` ORDER BY sp.TenSanPham ASC`; break;
            case 'price_asc': sqlQuery += ` ORDER BY sp.Gia ASC`; break;
            case 'price_desc': sqlQuery += ` ORDER BY sp.Gia DESC`; break;
            case 'best_seller': sqlQuery += ` ORDER BY ISNULL(sp.DaBan, 0) DESC`; break; // Đã sửa thành ISNULL
            case 'top_rated': sqlQuery += ` ORDER BY DiemDanhGia DESC, SoLuongDanhGia DESC`; break;
            default: sqlQuery += ` ORDER BY sp.Id DESC`;
        }

        let result = await pool.request().query(sqlQuery);
        res.json(result.recordset);
    } catch (err) {
        console.error("Lỗi API Products:", err);
        res.status(500).send(err.message);
    }
});

app.get('/api/products/:id', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let productRes = await pool.request().input('id', sql.Int, req.params.id).query('SELECT * FROM SanPham WHERE Id = @id');
        let variantRes = await pool.request().input('id', sql.Int, req.params.id).query('SELECT * FROM SanPhamBienThe WHERE SanPhamId = @id');
        res.json({ product: productRes.recordset[0], variants: variantRes.recordset });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// ==================== 3. GIỎ HÀNG ====================
app.get('/api/cart/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('userId', sql.Int, req.params.userId).query(`
            SELECT gh.Id, gh.SanPhamBienTheId, gh.SoLuong, bt.MauSac, bt.KichThuoc, sp.TenSanPham, sp.Gia, sp.HinhAnh, (sp.Gia * gh.SoLuong) AS ThanhTien
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
        if (!userId || !variantId || !quantity) return res.status(400).json({ status: 'error', message: 'Thiếu dữ liệu!' });

        let pool = await sql.connect(dbConfig);
        let checkVariant = await pool.request().input('variantId', sql.Int, variantId).query('SELECT Id FROM SanPhamBienThe WHERE Id = @variantId');
        if (checkVariant.recordset.length === 0) return res.status(404).json({ status: 'error', message: 'Không tìm thấy biến thể!' });

        await pool.request()
            .input('userId', sql.Int, userId)
            .input('variantId', sql.Int, variantId)
            .input('quantity', sql.Int, quantity)
            .query(`
                IF EXISTS (SELECT 1 FROM GioHang WHERE NguoiDungId = @userId AND SanPhamBienTheId = @variantId)
                    UPDATE GioHang SET SoLuong = SoLuong + @quantity WHERE NguoiDungId = @userId AND SanPhamBienTheId = @variantId;
                ELSE
                    INSERT INTO GioHang (NguoiDungId, SanPhamBienTheId, SoLuong) VALUES (@userId, @variantId, @quantity);
            `);
        res.json({ status: 'success', message: 'Đã thêm vào giỏ hàng!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/cart/:cartId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request().input('cartId', sql.Int, req.params.cartId).input('quantity', sql.Int, req.body.quantity).query('UPDATE GioHang SET SoLuong = @quantity WHERE Id = @cartId');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.delete('/api/cart/:cartId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request().input('cartId', sql.Int, req.params.cartId).query('DELETE FROM GioHang WHERE Id = @cartId');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// ==================== 4. YÊU THÍCH ====================
app.get('/api/favorites/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('userId', sql.Int, req.params.userId).query(`SELECT sp.* FROM YeuThich yt JOIN SanPham sp ON yt.SanPhamId = sp.Id WHERE yt.NguoiDungId = @userId`);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.post('/api/favorites/toggle', async (req, res) => {
    try {
        const { userId, productId } = req.body;
        let pool = await sql.connect(dbConfig);
        let check = await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).query('SELECT * FROM YeuThich WHERE NguoiDungId = @userId AND SanPhamId = @productId');

        if (check.recordset.length > 0) {
            await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).query('DELETE FROM YeuThich WHERE NguoiDungId = @userId AND SanPhamId = @productId');
            res.json({ status: 'success', message: 'Đã xóa khỏi Yêu thích' });
        } else {
            await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).query('INSERT INTO YeuThich (NguoiDungId, SanPhamId) VALUES (@userId, @productId)');
            res.json({ status: 'success', message: 'Đã thêm vào Yêu thích' });
        }
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 5. KHUYẾN MÃI ====================
app.get('/api/admin/promotions', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`SELECT Id, MaGiamGia, PhanTramGiam, ISNULL(SoLuong, 0) AS SoLuong, ISNULL(DaSuDung, 0) AS DaSuDung, MoTa, LoaiGiamGia FROM KhuyenMai ORDER BY Id DESC`);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.post('/api/admin/promotions', verifyAdmin, async (req, res) => {
    try {
        const { code, percent, limit, description, loaiGiamGia } = req.body;
        const percentNum = parseInt(percent, 10);
        const loai = parseInt(loaiGiamGia, 10) || 1;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('code', sql.NVarChar, code)
            .input('percent', sql.Int, percentNum)
            .input('limit', sql.Int, limit || 50)
            .input('description', sql.NVarChar, description || '')
            .input('loai', sql.Int, loai)
            .query(`INSERT INTO KhuyenMai (MaGiamGia, PhanTramGiam, SoLuong, DaSuDung, MoTa, NgayHetHan, LoaiGiamGia) VALUES (@code, @percent, @limit, 0, @description, DATEADD(MINUTE, 5, GETDATE()), @loai)`);
        res.json({ status: 'success', message: 'Tạo mã thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.get('/api/promotions/available', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`SELECT Id, MaGiamGia, PhanTramGiam, MoTa, SoLuong, DaSuDung, LoaiGiamGia FROM KhuyenMai ORDER BY Id DESC`);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/promotions/apply', async (req, res) => {
    try {
        const { code, totalAmount } = req.body;
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('code', sql.NVarChar, code).query('SELECT *, CASE WHEN NgayHetHan IS NOT NULL AND GETDATE() > NgayHetHan THEN 1 ELSE 0 END AS IsExpired FROM KhuyenMai WHERE MaGiamGia = @code');

        if (result.recordset.length === 0) return res.json({ status: 'error', message: 'Mã khuyến mãi không tồn tại!' });
        let promo = result.recordset[0];

        if (promo.IsExpired === 1) return res.json({ status: 'error', message: 'Mã khuyến mãi đã hết hạn!' });
        if ((promo.DaSuDung || 0) >= (promo.SoLuong || 0)) return res.json({ status: 'error', message: 'Mã đã hết lượt sử dụng!' });

        let discountPercent = promo.PhanTramGiam || 0;
        let discountAmount = (totalAmount * discountPercent) / 100;
        
        res.json({
            status: 'success',
            message: `Áp dụng thành công mã -${discountPercent}%`,
            discountAmount: discountAmount,
            discountPercent: discountPercent,
            loaiGiamGia: promo.LoaiGiamGia || 1
        });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 6. ĐƠN HÀNG ====================
app.get('/api/orders/user/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let ordersRes = await pool.request().input('userId', sql.Int, req.params.userId).query('SELECT * FROM DonHang WHERE NguoiDungId = @userId ORDER BY Id DESC');
        let orders = ordersRes.recordset;
        for (let order of orders) {
            let detailRes = await pool.request().input('orderId', sql.Int, order.Id).query(`
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
        let orderItems = items && items.length > 0 ? items : [];

        if (orderItems.length === 0) return res.status(400).json({ status: 'error', message: 'Không có sản phẩm!' });

        let orderRes = await pool.request()
            .input('userId', sql.Int, userId)
            .input('address', sql.NVarChar, address)
            .input('paymentMethod', sql.NVarChar, paymentMethod)
            .input('totalAmount', sql.Decimal(18, 2), totalAmount)
            .query(`INSERT INTO DonHang (NguoiDungId, DiaChiGiao, PhuongThucTT, TongTien, TrangThai, NgayTao) OUTPUT INSERTED.Id VALUES (@userId, @address, @paymentMethod, @totalAmount, N'ChoXacNhan', GETDATE())`);

        let orderId = orderRes.recordset[0].Id;

        for (let item of orderItems) {
            let variantId = item.SanPhamBienTheId || item.Id || item.variantId;
            let qty = item.SoLuong || item.quantity || 1;
            let price = item.Gia || item.price || 0;

            let checkExist = await pool.request().input('variantId', sql.Int, variantId).query('SELECT Id FROM SanPhamBienThe WHERE Id = @variantId');
            if (checkExist.recordset.length === 0) continue;

            await pool.request()
                .input('orderId', sql.Int, orderId)
                .input('variantId', sql.Int, variantId)
                .input('quantity', sql.Int, qty)
                .input('price', sql.Decimal(18, 2), price)
                .query('INSERT INTO ChiTietDonHang (DonHangId, SanPhamBienTheId, SoLuong, DonGia) VALUES (@orderId, @variantId, @quantity, @price)');

            await pool.request().input('variantId', sql.Int, variantId).input('quantity', sql.Int, qty).query('UPDATE SanPhamBienThe SET SoLuong = CASE WHEN SoLuong >= @quantity THEN SoLuong - @quantity ELSE 0 END WHERE Id = @variantId');
        }

        if (promoCode) {
            await pool.request().input('code', sql.NVarChar, promoCode).query('UPDATE KhuyenMai SET DaSuDung = ISNULL(DaSuDung, 0) + 1 WHERE MaGiamGia = @code');
        }

        await pool.request().input('userId', sql.Int, userId).query('DELETE FROM GioHang WHERE NguoiDungId = @userId');
        res.json({ status: 'success', message: 'Đặt hàng thành công!', orderId: orderId });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/orders/:orderId/cancel', async (req, res) => {
    try {
        const { userId } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);
        let orderCheck = await pool.request().input('orderId', sql.Int, orderId).input('userId', sql.Int, userId).query('SELECT * FROM DonHang WHERE Id = @orderId AND NguoiDungId = @userId');

        if (orderCheck.recordset.length === 0) return res.json({ status: 'error', message: 'Không tìm thấy đơn hàng!' });

        let order = orderCheck.recordset[0];
        if (order.TrangThai === 'ChoXacNhan') {
            let details = await pool.request().input('orderId', sql.Int, orderId).query('SELECT * FROM ChiTietDonHang WHERE DonHangId = @orderId');
            for (let item of details.recordset) {
                await pool.request().input('variantId', sql.Int, item.SanPhamBienTheId).input('quantity', sql.Int, item.SoLuong).query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @quantity WHERE Id = @variantId');
            }
            await pool.request().input('orderId', sql.Int, orderId).query('DELETE FROM ChiTietDonHang WHERE DonHangId = @orderId');
            await pool.request().input('orderId', sql.Int, orderId).query('DELETE FROM DonHang WHERE Id = @orderId');
            return res.json({ status: 'success', message: 'Đã hủy đơn và hoàn kho!' });
        } else {
            await pool.request().input('orderId', sql.Int, orderId).query("UPDATE DonHang SET TrangThai = N'DaHuy' WHERE Id = @orderId");
            return res.json({ status: 'success', message: 'Đã hủy đơn hàng!' });
        }
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/orders/:orderId/return', async (req, res) => {
    try {
        const { userId, reason } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);
        let check = await pool.request().input('id', sql.Int, orderId).input('userId', sql.Int, userId).query("SELECT * FROM DonHang WHERE Id = @id AND NguoiDungId = @userId AND TrangThai = N'DaGiao'");

        if (check.recordset.length === 0) return res.status(400).json({ status: 'error', message: 'Đơn hàng không hợp lệ!' });

        await pool.request().input('id', sql.Int, orderId).input('reason', sql.NVarChar, reason).query("UPDATE DonHang SET TrangThaiHoan = N'ChoDuyet', LyDoHoan = @reason WHERE Id = @id");
        res.json({ status: 'success', message: 'Đã gửi yêu cầu hoàn đơn!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/admin/orders/:orderId/approve-return', verifyAdmin, async (req, res) => {
    try {
        const { isApproved } = req.body;
        const orderId = req.params.orderId;
        let pool = await sql.connect(dbConfig);

        if (isApproved) {
            let details = await pool.request().input('orderId', sql.Int, orderId).query('SELECT SanPhamBienTheId, SoLuong FROM ChiTietDonHang WHERE DonHangId = @orderId');
            for (let item of details.recordset) {
                await pool.request().input('variantId', sql.Int, item.SanPhamBienTheId).input('qty', sql.Int, item.SoLuong).query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @qty WHERE Id = @variantId');
            }
            await pool.request().input('id', sql.Int, orderId).query("UPDATE DonHang SET TrangThai = N'DaHuy', TrangThaiHoan = N'DaDuyet' WHERE Id = @id");
        } else {
            await pool.request().input('id', sql.Int, orderId).query("UPDATE DonHang SET TrangThaiHoan = N'TuChoi' WHERE Id = @id");
        }
        res.json({ status: 'success', message: isApproved ? 'Đã duyệt hoàn đơn!' : 'Đã từ chối!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 7. ADMIN (KHÁCH, ĐƠN, SẢN PHẨM) ====================
app.get('/api/admin/orders', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`SELECT dh.*, nd.HoTen, nd.Email FROM DonHang dh JOIN NguoiDung nd ON dh.NguoiDungId = nd.Id ORDER BY dh.Id DESC`);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.put('/api/admin/orders/:id/status', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request().input('id', sql.Int, req.params.id).input('status', sql.NVarChar, req.body.status).query('UPDATE DonHang SET TrangThai = @status WHERE Id = @id');
        res.json({ status: 'success', message: 'Cập nhật thành công!' });
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.get('/api/admin/customers', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query("SELECT Id, HoTen, Email, SoDienThoai, VaiTro, TrangThai FROM NguoiDung WHERE LOWER(TRIM(VaiTro)) != 'admin'");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.delete('/api/admin/customers/:id', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM GioHang WHERE NguoiDungId = @id');
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM YeuThich WHERE NguoiDungId = @id');
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM NguoiDung WHERE Id = @id');
        res.json({ status: 'success', message: 'Đã xóa tài khoản!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/admin/customers/:id/toggle-status', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let userRes = await pool.request().input('id', sql.Int, req.params.id).query('SELECT TrangThai FROM NguoiDung WHERE Id = @id');
        if (userRes.recordset.length === 0) return res.status(404).json({ status: 'error', message: 'Không tìm thấy!' });

        let newStatus = userRes.recordset[0].TrangThai === 'BiKhoa' ? 'HoatDong' : 'BiKhoa';
        await pool.request().input('id', sql.Int, req.params.id).input('status', sql.NVarChar, newStatus).query('UPDATE NguoiDung SET TrangThai = @status WHERE Id = @id');
        res.json({ status: 'success', message: `Đã ${newStatus === 'BiKhoa' ? 'khóa' : 'mở khóa'}!` });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/admin/products', verifyAdmin, async (req, res) => {
    try {
        const { name, categoryId, price, image, description } = req.body;
        let pool = await sql.connect(dbConfig);
        // BỔ SUNG CỘT IsMoi, DaBan MẶC ĐỊNH ĐỂ TRÁNH LỖI
        let result = await pool.request()
            .input('name', sql.NVarChar, name)
            .input('categoryId', sql.Int, categoryId)
            .input('price', sql.Decimal(18, 2), price)
            .input('image', sql.NVarChar, image)
            .input('description', sql.NVarChar, description)
            .query(`INSERT INTO SanPham (TenSanPham, DanhMucId, Gia, HinhAnh, MoTa, IsMoi, DaBan) OUTPUT INSERTED.Id VALUES (@name, @categoryId, @price, @image, @description, 1, 0)`);
        res.json({ status: 'success', message: 'Thêm thành công!', productId: result.recordset[0].Id });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.delete('/api/admin/products/:id', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM SanPhamBienThe WHERE SanPhamId = @id');
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM YeuThich WHERE SanPhamId = @id');
        await pool.request().input('id', sql.Int, req.params.id).query('DELETE FROM SanPham WHERE Id = @id');
        res.json({ status: 'success', message: 'Xóa thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.put('/api/admin/products/:id', verifyAdmin, async (req, res) => {
    try {
        const { name, categoryId, price, image, description } = req.body;
        let pool = await sql.connect(dbConfig);
        await pool.request()
            .input('id', sql.Int, req.params.id)
            .input('name', sql.NVarChar, name)
            .input('categoryId', sql.Int, categoryId)
            .input('price', sql.Decimal(18, 2), price)
            .input('image', sql.NVarChar, image)
            .input('description', sql.NVarChar, description)
            .query(`UPDATE SanPham SET TenSanPham = @name, DanhMucId = @categoryId, Gia = @price, HinhAnh = @image, MoTa = @description WHERE Id = @id`);
        res.json({ status: 'success', message: 'Cập nhật thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/admin/inventory/import', verifyAdmin, async (req, res) => {
    try {
        const { sanPhamId, mauSac, kichThuoc, soLuongNhap } = req.body;
        let pool = await sql.connect(dbConfig);
        let checkVariant = await pool.request().input('sanPhamId', sql.Int, sanPhamId).input('mauSac', sql.NVarChar, mauSac).input('kichThuoc', sql.NVarChar, kichThuoc).query('SELECT Id FROM SanPhamBienThe WHERE SanPhamId = @sanPhamId AND MauSac = @mauSac AND KichThuoc = @kichThuoc');

        if (checkVariant.recordset.length > 0) {
            await pool.request().input('id', sql.Int, checkVariant.recordset[0].Id).input('soLuong', sql.Int, soLuongNhap).query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @soLuong WHERE Id = @id');
        } else {
            await pool.request().input('sanPhamId', sql.Int, sanPhamId).input('mauSac', sql.NVarChar, mauSac).input('kichThuoc', sql.NVarChar, kichThuoc).input('soLuong', sql.Int, soLuongNhap).query('INSERT INTO SanPhamBienThe (SanPhamId, MauSac, KichThuoc, SoLuong) VALUES (@sanPhamId, @mauSac, @kichThuoc, @soLuong)');
        }
        res.json({ status: 'success', message: 'Nhập kho thành công!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 8. THỐNG KÊ & TỒN KHO ====================
app.get('/api/admin/statistics', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let revenueRes = await pool.request().query(`SELECT ISNULL(SUM(TongTien), 0) AS TotalRevenue FROM DonHang WHERE TrangThai != 'DaHuy'`);
        let ordersRes = await pool.request().query('SELECT COUNT(Id) AS TotalOrders FROM DonHang');
        let customersRes = await pool.request().query("SELECT COUNT(Id) AS TotalCustomers FROM NguoiDung WHERE VaiTro = 'KhachHang'");
        let chartRes = await pool.request().query(`
            SELECT FORMAT(NgayTao, 'dd/MM') AS Ngay, SUM(TongTien) AS DoanhThu
            FROM DonHang WHERE TrangThai != 'DaHuy' AND NgayTao >= DATEADD(day, -6, GETDATE())
            GROUP BY FORMAT(NgayTao, 'dd/MM'), CAST(NgayTao AS DATE) ORDER BY CAST(NgayTao AS DATE) ASC
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

app.get('/api/admin/inventory', verifyAdmin, async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().query(`
            SELECT bt.Id AS BienTheId, sp.TenSanPham, sp.HinhAnh, bt.MauSac, bt.KichThuoc, bt.SoLuong
            FROM SanPhamBienThe bt JOIN SanPham sp ON bt.SanPhamId = sp.Id
            ORDER BY bt.SoLuong ASC, sp.TenSanPham ASC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 9. ĐÁNH GIÁ & CHAT ====================
app.get('/api/reviews/:productId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('productId', sql.Int, req.params.productId).query(`
            SELECT dg.Id, dg.SoSao, dg.BinhLuan, dg.NgayDanhGia, nd.HoTen
            FROM DanhGia dg JOIN NguoiDung nd ON dg.NguoiDungId = nd.Id
            WHERE dg.SanPhamId = @productId ORDER BY dg.NgayDanhGia DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.get('/api/reviews/user/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('userId', sql.Int, req.params.userId).query(`
            SELECT dg.Id, dg.SoSao, dg.BinhLuan, dg.NgayDanhGia, sp.TenSanPham, sp.HinhAnh, sp.Id AS SanPhamId
            FROM DanhGia dg JOIN SanPham sp ON dg.SanPhamId = sp.Id
            WHERE dg.NguoiDungId = @userId ORDER BY dg.NgayDanhGia DESC
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/reviews', async (req, res) => {
    try {
        const { userId, productId, soSao, binhLuan } = req.body;
        let pool = await sql.connect(dbConfig);
        let checkBought = await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).query(`
            SELECT dh.Id FROM DonHang dh JOIN ChiTietDonHang ct ON dh.Id = ct.DonHangId JOIN SanPhamBienThe bt ON ct.SanPhamBienTheId = bt.Id
            WHERE dh.NguoiDungId = @userId AND bt.SanPhamId = @productId AND dh.TrangThai = N'DaGiao'
        `);
        if (checkBought.recordset.length === 0) return res.status(400).json({ status: 'error', message: 'Bạn phải mua hàng mới được đánh giá!' });

        let checkReviewed = await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).query('SELECT Id FROM DanhGia WHERE NguoiDungId = @userId AND SanPhamId = @productId');
        if (checkReviewed.recordset.length > 0) return res.status(400).json({ status: 'error', message: 'Bạn đã đánh giá rồi!' });

        await pool.request().input('userId', sql.Int, userId).input('productId', sql.Int, productId).input('soSao', sql.Int, soSao).input('binhLuan', sql.NVarChar, binhLuan).query('INSERT INTO DanhGia (NguoiDungId, SanPhamId, SoSao, BinhLuan) VALUES (@userId, @productId, @soSao, @binhLuan)');
        res.json({ status: 'success', message: 'Cảm ơn bạn đã đánh giá!' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.get('/api/chat/:userId', async (req, res) => {
    try {
        let pool = await sql.connect(dbConfig);
        let result = await pool.request().input('userId', sql.Int, req.params.userId).query('SELECT * FROM TinNhanChat WHERE NguoiDungId = @userId ORDER BY ThoiGian ASC');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

app.post('/api/chat', async (req, res) => {
    try {
        const { userId, sender, message } = req.body;
        let pool = await sql.connect(dbConfig);
        await pool.request().input('userId', sql.Int, userId).input('sender', sql.NVarChar, sender).input('message', sql.NVarChar, message).query('INSERT INTO TinNhanChat (NguoiDungId, NguoiGui, NoiDung) VALUES (@userId, @sender, @message)');
        res.json({ status: 'success' });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

// ==================== 10. ROBOT TỰ ĐỘNG ====================
setInterval(async () => {
    try {
        let pool = await sql.connect(dbConfig);
        let check1 = await pool.request().query(`UPDATE DonHang SET TrangThai = N'DaXacNhan' OUTPUT INSERTED.Id WHERE Id IN (SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'ChoXacNhan')`);
        if (check1.recordset.length > 0) return;

        let check2 = await pool.request().query(`UPDATE DonHang SET TrangThai = N'DangGiao' OUTPUT INSERTED.Id WHERE Id IN (SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'DaXacNhan')`);
        if (check2.recordset.length > 0) return;

        let deliveringOrders = await pool.request().query(`SELECT TOP 1 Id FROM DonHang WHERE TrangThai = N'DangGiao'`);
        if (deliveringOrders.recordset.length > 0) {
            let orderId = deliveringOrders.recordset[0].Id;
            let isSuccess = Math.random() < 0.5;
            let newStatus = isSuccess ? 'DaGiao' : 'DaHuy';

            await pool.request().input('id', sql.Int, orderId).input('status', sql.NVarChar, newStatus).query('UPDATE DonHang SET TrangThai = @status, NgayGiaoHang = GETDATE() WHERE Id = @id');
            if (!isSuccess) {
                let details = await pool.request().input('orderId', sql.Int, orderId).query('SELECT SanPhamBienTheId, SoLuong FROM ChiTietDonHang WHERE DonHangId = @orderId');
                for (let item of details.recordset) {
                    await pool.request().input('variantId', sql.Int, item.SanPhamBienTheId).input('qty', sql.Int, item.SoLuong).query('UPDATE SanPhamBienThe SET SoLuong = SoLuong + @qty WHERE Id = @variantId');
                }
            }
        }
    } catch (err) {
        console.error('Lỗi Robot:', err.message);
    }
}, 30000);

const PORT = 3000;
app.listen(PORT, () => console.log(`🚀 Backend Server API đang chạy tại http://localhost:${PORT}`));