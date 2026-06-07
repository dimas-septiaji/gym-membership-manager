<?php
// Ganti sesuai konfigurasi hosting kamu
$host   = 'localhost';
$user   = 'root';        // ganti dengan username database hosting
$pass   = '';            // ganti dengan password database hosting
$db     = 'gym_member';  // ganti dengan nama database kamu

$conn = mysqli_connect($host, $user, $pass, $db);

if (!$conn) {
    header('Content-Type: application/json');
    echo json_encode([
        "status"  => false,
        "message" => "Koneksi database gagal: " . mysqli_connect_error()
    ]);
    exit;
}

mysqli_set_charset($conn, "utf8");
?>
