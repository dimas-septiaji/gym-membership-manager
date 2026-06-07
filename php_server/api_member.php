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

$query = "SELECT 
    m.id,
    m.nama,
    m.telp,
    m.alamat,
    m.membership_id,
    p.nama_paket,
    m.tanggal_daftar,
    m.tanggal_expired,
    DATEDIFF(m.tanggal_expired, CURDATE()) AS sisa_hari,
    CASE 
        WHEN m.tanggal_expired IS NULL THEN 'Expired'
        WHEN DATEDIFF(m.tanggal_expired, CURDATE()) > 0 THEN 'Aktif'
        ELSE 'Expired'
    END AS status_membership
FROM member m
LEFT JOIN paket p ON m.membership_id = p.id
ORDER BY m.id DESC";

$result = mysqli_query($conn, $query);

if (!$result) {
    echo json_encode([
        "status"  => false,
        "message" => "Query error: " . mysqli_error($conn)
    ]);
    exit;
}

$data = [];
while ($row = mysqli_fetch_assoc($result)) {
    $row['sisa_hari'] = (int)($row['sisa_hari'] ?? 0);
    $data[] = $row;
}

echo json_encode([
    "status" => true,
    "data"   => $data
]);
?>
