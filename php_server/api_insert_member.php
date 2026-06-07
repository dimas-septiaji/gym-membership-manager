<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include "koneksi.php";

$nama         = trim($_POST['nama'] ?? '');
$telp         = trim($_POST['telp'] ?? '');
$alamat       = trim($_POST['alamat'] ?? '');
$membership_id = trim($_POST['membership_id'] ?? '');

// Validasi input wajib
if ($nama === '' || $telp === '' || $alamat === '' || $membership_id === '') {
    echo json_encode([
        "status"  => false,
        "message" => "Semua field wajib diisi (nama, telp, alamat, membership_id)"
    ]);
    exit;
}

if (!is_numeric($membership_id)) {
    echo json_encode([
        "status"  => false,
        "message" => "Membership ID harus berupa angka"
    ]);
    exit;
}

// Hitung tanggal berdasarkan paket
$paket = mysqli_query($conn, "SELECT durasi_hari FROM paket WHERE id = " . (int)$membership_id);
if (!$paket || mysqli_num_rows($paket) === 0) {
    echo json_encode([
        "status"  => false,
        "message" => "Paket membership tidak ditemukan"
    ]);
    exit;
}
$paketData     = mysqli_fetch_assoc($paket);
$durasi        = (int)($paketData['durasi_hari'] ?? 30);
$tgl_daftar    = date('Y-m-d');
$tgl_expired   = date('Y-m-d', strtotime("+$durasi days"));

$stmt = mysqli_prepare($conn,
    "INSERT INTO member (nama, telp, alamat, membership_id, tanggal_daftar, tanggal_expired)
     VALUES (?, ?, ?, ?, ?, ?)"
);

if (!$stmt) {
    echo json_encode([
        "status"  => false,
        "message" => "Prepare error: " . mysqli_error($conn)
    ]);
    exit;
}

mysqli_stmt_bind_param($stmt, "sssiss", $nama, $telp, $alamat, $membership_id, $tgl_daftar, $tgl_expired);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        "status"  => true,
        "message" => "Member berhasil ditambahkan"
    ]);
} else {
    echo json_encode([
        "status"  => false,
        "message" => "Gagal insert: " . mysqli_stmt_error($stmt)
    ]);
}

mysqli_stmt_close($stmt);
?>
