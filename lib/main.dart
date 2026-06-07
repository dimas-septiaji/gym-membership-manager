import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  runApp(const MyApp());
}

// ============================================================
// SOLVER anti-bot InfinityFree
// Setiap request dicek — kalau balik HTML challenge, decrypt
// cookie AES lalu retry dengan cookie tsb.
// ============================================================
class ApiClient {
  String? _challengeCookie;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 11; Redmi Note 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String? _solveChallenge(String html) {
    try {
      // HTML format: var a=toNumbers("..."),b=toNumbers("..."),c=toNumbers("...")
      // Pakai regex tanpa "var" supaya cocok untuk b= dan c= juga
      final aMatch = RegExp(r'a=toNumbers\("([a-f0-9]+)"\)').firstMatch(html);
      final bMatch = RegExp(r'b=toNumbers\("([a-f0-9]+)"\)').firstMatch(html);
      final cMatch = RegExp(r'c=toNumbers\("([a-f0-9]+)"\)').firstMatch(html);
      if (aMatch == null || bMatch == null || cMatch == null) {
        debugPrint('Regex tidak cocok!');
        return null;
      }

      debugPrint('a=${aMatch.group(1)}, b=${bMatch.group(1)}, c=${cMatch.group(1)}');

      final keyBytes   = _hexToBytes(aMatch.group(1)!);
      final ivBytes    = _hexToBytes(bMatch.group(1)!);
      final cipherBytes = _hexToBytes(cMatch.group(1)!);

      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv  = enc.IV(Uint8List.fromList(ivBytes));
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: null),
      );
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: iv,
      );

      final cookieVal = _bytesToHex(decrypted);
      debugPrint('Cookie solved: __test=$cookieVal');
      return '__test=$cookieVal';
    } catch (e) {
      debugPrint('Challenge solve error: $e');
      return null;
    }
  }

  bool _isChallenge(String body) => body.contains('slowAES');

  Map<String, String> _buildHeaders() => {
    'User-Agent': _userAgent,
    if (_challengeCookie != null) 'Cookie': _challengeCookie!,
  };

  Future<void> _solveAndCache(String url, String challengeHtml) async {
    final cookie = _solveChallenge(challengeHtml);
    if (cookie == null) return;
    _challengeCookie = cookie;

    // Simulasikan redirect browser ke ?i=1 dengan cookie
    final headers = _buildHeaders();
    debugPrint('Hitting $url?i=1 dengan cookie...');
    await http.get(Uri.parse('$url?i=1'), headers: headers);
  }

  Future<http.Response> get(String url) async {
    var res = await http.get(Uri.parse(url), headers: _buildHeaders());
    if (_isChallenge(res.body)) {
      debugPrint('Challenge detected (GET), solving...');
      await _solveAndCache(url, res.body);
      res = await http.get(Uri.parse(url), headers: _buildHeaders());
    }
    return res;
  }

  Future<http.Response> post(String url, Map<String, String> body) async {
    // Kalau belum punya cookie, lakukan GET dulu untuk solve challenge
    if (_challengeCookie == null) {
      final probe = await http.get(Uri.parse(url), headers: _buildHeaders());
      if (_isChallenge(probe.body)) {
        debugPrint('Challenge detected (probe), solving...');
        await _solveAndCache(url, probe.body);
      }
    }

    var res = await http.post(
      Uri.parse(url),
      body: body,
      headers: _buildHeaders(),
    );

    if (_isChallenge(res.body)) {
      debugPrint('Challenge detected (POST), solving...');
      await _solveAndCache(url, res.body);
      res = await http.post(
        Uri.parse(url),
        body: body,
        headers: _buildHeaders(),
      );
    }
    return res;
  }

  Future<http.Response> postJson(String url, Map<String, dynamic> bodyJson) async {
    final bodyStr = jsonEncode(bodyJson);
    final headers = _buildHeaders()..addAll({'Content-Type': 'application/json'});
    
    if (_challengeCookie == null) {
      final probe = await http.get(Uri.parse(url), headers: _buildHeaders());
      if (_isChallenge(probe.body)) {
        debugPrint('Challenge detected (probe), solving...');
        await _solveAndCache(url, probe.body);
        if (_challengeCookie != null) headers['Cookie'] = _challengeCookie!;
      }
    }

    var res = await http.post(Uri.parse(url), body: bodyStr, headers: headers);

    if (_isChallenge(res.body)) {
      debugPrint('Challenge detected (POST Json), solving...');
      await _solveAndCache(url, res.body);
      if (_challengeCookie != null) headers['Cookie'] = _challengeCookie!;
      res = await http.post(Uri.parse(url), body: bodyStr, headers: headers);
    }
    return res;
  }
}


class Member {
  final String id;
  final String nama;
  final String telp;
  final String alamat;
  final String membershipId;
  final String namaPaket;
  final String tanggalDaftar;
  final String tanggalExpired;
  final int sisaHari;
  final String statusMembership;

  Member({
    required this.id,
    required this.nama,
    required this.telp,
    required this.alamat,
    required this.membershipId,
    required this.namaPaket,
    required this.tanggalDaftar,
    required this.tanggalExpired,
    required this.sisaHari,
    required this.statusMembership,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      telp: json['telp']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '',
      membershipId: json['membership_id']?.toString() ?? '',
      namaPaket: json['nama_paket']?.toString() ?? '',
      tanggalDaftar: json['tanggal_daftar']?.toString() ?? '',
      tanggalExpired: json['tanggal_expired']?.toString() ?? '',
      sisaHari: int.tryParse(json['sisa_hari'].toString()) ?? 0,
      statusMembership: json['status_membership']?.toString() ?? 'Aktif',
    );
  }
}

// ================= MODEL MEMBERSHIP =================
class Membership {
  final String id;
  final String namaPaket;
  final int durasibulan;

  Membership({
    required this.id,
    required this.namaPaket,
    required this.durasibulan,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id']?.toString() ?? '',
      namaPaket: json['nama_paket']?.toString() ?? '',
      durasibulan: int.tryParse(json['durasi_bulan'].toString()) ?? 0,
    );
  }
}

// ================= MODEL PRODUK & CART =================
class Produk {
  final String id;
  final String namaProduk;
  final double harga;
  final int stok;

  Produk({required this.id, required this.namaProduk, required this.harga, required this.stok});

  factory Produk.fromJson(Map<String, dynamic> json) {
    return Produk(
      id: json['id']?.toString() ?? '',
      namaProduk: json['nama_produk']?.toString() ?? '',
      harga: double.tryParse(json['harga'].toString()) ?? 0.0,
      stok: int.tryParse(json['stok'].toString()) ?? 0,
    );
  }
}

class CartItem {
  final Produk produk;
  int qty;

  CartItem({required this.produk, required this.qty});
}

class Penjualan {
  final String id;
  final String tanggal;
  final double total;

  Penjualan({required this.id, required this.tanggal, required this.total});

  factory Penjualan.fromJson(Map<String, dynamic> json) {
    return Penjualan(
      id: json['id']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      total: double.tryParse(json['total'].toString()) ?? 0.0,
    );
  }
}

class DetailPenjualan {
  final String namaProduk;
  final double harga;
  final int qty;
  final double subtotal;

  DetailPenjualan({required this.namaProduk, required this.harga, required this.qty, required this.subtotal});

  factory DetailPenjualan.fromJson(Map<String, dynamic> json) {
    return DetailPenjualan(
      namaProduk: json['nama_produk']?.toString() ?? '',
      harga: double.tryParse(json['harga'].toString()) ?? 0.0,
      qty: int.tryParse(json['qty'].toString()) ?? 0,
      subtotal: double.tryParse(json['subtotal'].toString()) ?? 0.0,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MemberPage(),
    );
  }
}

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final String baseUrl = 'https://gym-membership.page.gd';
  final ApiClient _api = ApiClient();

  List<Member> members = [];
  List<Membership> memberships = [];
  bool loading = false;

  final namaC = TextEditingController();
  final telpC = TextEditingController();
  final alamatC = TextEditingController();
  String? selectedMembershipId;

  @override
  void initState() {
    super.initState();
    fetchMember();
    fetchMemberships();
  }

  @override
  void dispose() {
    namaC.dispose();
    telpC.dispose();
    alamatC.dispose();
    super.dispose();
  }

  // ================= FETCH =================
  Future<void> fetchMember() async {
    setState(() => loading = true);

    try {
      final res = await _api.get('$baseUrl/api_member.php');

      debugPrint("FETCH STATUS: ${res.statusCode}");
      debugPrint("FETCH BODY: ${res.body.substring(0, res.body.length.clamp(0, 300))}");

      if (res.statusCode != 200) throw Exception("Server error ${res.statusCode}");

      final decoded = jsonDecode(res.body);

      if (decoded is! Map || decoded['status'] != true) {
        throw Exception("API error: ${decoded['message'] ?? 'format salah'}");
      }

      final List data = decoded['data'];
      setState(() {
        members = data.map((e) => Member.fromJson(e)).toList();
      });
    } catch (e) {
      showMsg("FETCH ERROR: $e");
    }

    setState(() => loading = false);
  }

  // ================= FETCH MEMBERSHIPS =================
  Future<void> fetchMemberships() async {
    try {
      final res = await _api.get('$baseUrl/api_membership.php');
      final decoded = jsonDecode(res.body);
      if (decoded['status'] == true) {
        final List data = decoded['data'];
        setState(() {
          memberships = data.map((e) => Membership.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch memberships error: $e');
    }
  }

  // ================= INSERT =================
  Future<void> insertMember() async {
    try {
      final res = await _api.post('$baseUrl/api_insert_member.php', {
        'nama': namaC.text.trim(),
        'telp': telpC.text.trim(),
        'alamat': alamatC.text.trim(),
        'membership_id': selectedMembershipId ?? '',
      });

      debugPrint("INSERT BODY: ${res.body}");

      final decoded = jsonDecode(res.body);

      if (decoded['status'] == true) {
        clearForm();
        if (mounted) Navigator.pop(context);
        await fetchMember();
        showMsg("Berhasil tambah member");
      } else {
        showMsg(decoded['message'] ?? "Insert gagal");
      }
    } catch (e) {
      showMsg("INSERT ERROR: $e");
    }
  }

  // ================= UPDATE =================
  Future<void> updateMember(String id) async {
    try {
      final res = await _api.post('$baseUrl/api_update_member.php', {
        'id': id,
        'nama': namaC.text.trim(),
        'telp': telpC.text.trim(),
        'alamat': alamatC.text.trim(),
        'membership_id': selectedMembershipId ?? '',
      });

      debugPrint("UPDATE BODY: ${res.body}");

      final decoded = jsonDecode(res.body);

      if (decoded['status'] == true) {
        clearForm();
        if (mounted) Navigator.pop(context);
        await fetchMember();
        showMsg("Berhasil update member");
      } else {
        showMsg(decoded['message'] ?? "Update gagal");
      }
    } catch (e) {
      showMsg("UPDATE ERROR: $e");
    }
  }

  // ================= DELETE =================
  Future<void> deleteMember(String id) async {
    try {
      final res = await _api.post('$baseUrl/api_delete_member.php', {'id': id});

      debugPrint("DELETE BODY: ${res.body}");

      final decoded = jsonDecode(res.body);

      if (decoded['status'] == true) {
        await fetchMember();
        showMsg("Berhasil hapus member");
      } else {
        showMsg("Gagal hapus");
      }
    } catch (e) {
      showMsg("DELETE ERROR: $e");
    }
  }

  // ================= UTIL =================
  void clearForm() {
    namaC.clear();
    telpC.clear();
    alamatC.clear();
    setState(() => selectedMembershipId = null);
  }

  void showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= FORM =================
  void openForm({Member? m}) {
    if (m != null) {
      namaC.text = m.nama;
      telpC.text = m.telp;
      alamatC.text = m.alamat;
      selectedMembershipId = m.membershipId;
    } else {
      namaC.clear();
      telpC.clear();
      alamatC.clear();
      selectedMembershipId = null;
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m == null ? "Tambah Member" : "Edit Member",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: namaC, decoration: const InputDecoration(labelText: "Nama")),
                  TextField(controller: telpC, decoration: const InputDecoration(labelText: "Telp"), keyboardType: TextInputType.phone),
                  TextField(controller: alamatC, decoration: const InputDecoration(labelText: "Alamat")),
                  const SizedBox(height: 8),
                  // ======= DROPDOWN MEMBERSHIP =======
                  DropdownButtonFormField<String>(
                    value: selectedMembershipId,
                    decoration: const InputDecoration(
                      labelText: "Paket Membership",
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text("Pilih paket..."),
                    items: memberships.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text('${p.namaPaket} (${p.durasibulan} bulan)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() => selectedMembershipId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => m == null ? insertMember() : updateMember(m.id),
                      child: Text(m == null ? "Simpan" : "Update"),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= ITEM =================
  Widget item(Member m) {
    return Card(
      child: ListTile(
        title: Text(m.nama),
        subtitle: Text(
          "${m.telp}\n${m.namaPaket}\nStatus: ${m.statusMembership} (${m.sisaHari} hari)",
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          onSelected: (v) {
            if (v == 'edit') openForm(m: m);
            if (v == 'hapus') deleteMember(m.id);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text("Edit")),
            PopupMenuItem(value: 'hapus', child: Text("Hapus")),
          ],
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Gym CRUD"),
        actions: [
          IconButton(onPressed: fetchMember, icon: const Icon(Icons.refresh)),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("Gym Manager", style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Kelola Member"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text("Kasir Penjualan"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PenjualanPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Riwayat Penjualan"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPenjualanPage()));
              },
            ),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
              ? const Center(child: Text("Belum ada member"))
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (_, i) => item(members[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ================= HALAMAN KASIR PENJUALAN =================
class PenjualanPage extends StatefulWidget {
  const PenjualanPage({super.key});

  @override
  State<PenjualanPage> createState() => _PenjualanPageState();
}

class _PenjualanPageState extends State<PenjualanPage> {
  final String baseUrl = 'https://gym-membership.page.gd';
  final ApiClient _api = ApiClient();

  List<Produk> produkList = [];
  List<CartItem> cart = [];
  bool loading = false;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    fetchProduk();
  }

  Future<void> fetchProduk() async {
    setState(() => loading = true);
    try {
      final res = await _api.get('$baseUrl/api_produk.php');
      debugPrint("PRODUK BODY: ${res.body}");
      
      final decoded = jsonDecode(res.body);
      
      if (decoded is List) {
        // Jika API langsung mengembalikan array [...]
        setState(() {
          produkList = decoded.map((e) => Produk.fromJson(e)).toList();
        });
      } else if (decoded is Map && decoded['status'] == true) {
        // Jika API mengembalikan object {"status": true, "data": [...]}
        final List data = decoded['data'];
        setState(() {
          produkList = data.map((e) => Produk.fromJson(e)).toList();
        });
      } else if (decoded is Map) {
        debugPrint("PRODUK FAILED: ${decoded['message']}");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal muat produk: ${decoded['message']}")));
      } else {
        throw Exception("Format JSON tidak dikenali");
      }
    } catch (e) {
      debugPrint("FETCH PRODUK ERROR: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error API Produk: $e")));
    }
    setState(() => loading = false);
  }

  void addToCart(Produk p) {
    setState(() {
      final idx = cart.indexWhere((item) => item.produk.id == p.id);
      if (idx >= 0) {
        if (cart[idx].qty < p.stok) cart[idx].qty++;
      } else {
        if (p.stok > 0) cart.add(CartItem(produk: p, qty: 1));
      }
    });
  }

  void removeFromCart(Produk p) {
    setState(() {
      final idx = cart.indexWhere((item) => item.produk.id == p.id);
      if (idx >= 0) {
        if (cart[idx].qty > 1) {
          cart[idx].qty--;
        } else {
          cart.removeAt(idx);
        }
      }
    });
  }

  int getQty(Produk p) {
    final idx = cart.indexWhere((item) => item.produk.id == p.id);
    return idx >= 0 ? cart[idx].qty : 0;
  }

  double get totalBelanja {
    double total = 0;
    for (var item in cart) {
      total += item.produk.harga * item.qty;
    }
    return total;
  }

  Future<void> checkout() async {
    if (cart.isEmpty) return;

    setState(() => processing = true);
    try {
      final List<Map<String, dynamic>> items = cart.map((c) => {
        'produk_id': c.produk.id,
        'qty': c.qty,
      }).toList();

      final res = await _api.postJson('$baseUrl/api_transaksi.php', {'items': items});
      
      final text = res.body;
      debugPrint("API TRANSAKSI STATUS: ${res.statusCode}");
      debugPrint("API TRANSAKSI BODY: '$text'");

      if (text.trim().isEmpty) {
        throw Exception("Respons dari server kosong. Kemungkinan ada salah ketik (Syntax Error) saat mengedit file api_transaksi.php di hosting.");
      }
      
      if (text.startsWith('<')) { // In case it crashes and returns HTML error
        throw Exception("Server Error: Pastikan file api_transaksi.php sudah benar dan bebas dari mysqli_stmt_get_result.");
      }
      
      final decoded = jsonDecode(text);
      if (decoded['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaksi berhasil!")));
        setState(() {
          cart.clear();
        });
        fetchProduk(); // refresh stok
      } else {
        throw Exception(decoded['message'] ?? 'Checkout gagal');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error API: $e")));
    }
    setState(() => processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir Penjualan"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: produkList.length,
              itemBuilder: (ctx, i) {
                final p = produkList[i];
                final qty = getQty(p);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(p.namaProduk),
                    subtitle: Text("Rp ${p.harga.toStringAsFixed(0)} | Stok: ${p.stok}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: qty > 0 ? () => removeFromCart(p) : null,
                        ),
                        Text(qty.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: qty < p.stok ? () => addToCart(p) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("Rp ${totalBelanja.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: (cart.isEmpty || processing) ? null : checkout,
                child: processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Checkout"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ================= HALAMAN HISTORY PENJUALAN =================
class HistoryPenjualanPage extends StatefulWidget {
  const HistoryPenjualanPage({super.key});

  @override
  State<HistoryPenjualanPage> createState() => _HistoryPenjualanPageState();
}

class _HistoryPenjualanPageState extends State<HistoryPenjualanPage> {
  final String baseUrl = 'https://gym-membership.page.gd';
  final ApiClient _api = ApiClient();

  List<Penjualan> historyList = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() => loading = true);
    try {
      final res = await _api.get('$baseUrl/api_history_penjualan.php');
      final decoded = jsonDecode(res.body);
      if (decoded['status'] == true) {
        final List data = decoded['data'];
        setState(() {
          historyList = data.map((e) => Penjualan.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("FETCH HISTORY ERROR: $e");
    }
    setState(() => loading = false);
  }

  void showDetail(Penjualan p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DetailPenjualanSheet(penjualan: p, api: _api, baseUrl: baseUrl);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Penjualan")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : historyList.isEmpty
              ? const Center(child: Text("Belum ada transaksi"))
              : ListView.builder(
                  itemCount: historyList.length,
                  itemBuilder: (ctx, i) {
                    final p = historyList[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text("Order #${p.id}"),
                        subtitle: Text("Tanggal: ${p.tanggal}\nTotal: Rp ${p.total.toStringAsFixed(0)}"),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDetail(p),
                      ),
                    );
                  },
                ),
    );
  }
}

class DetailPenjualanSheet extends StatefulWidget {
  final Penjualan penjualan;
  final ApiClient api;
  final String baseUrl;
  
  const DetailPenjualanSheet({super.key, required this.penjualan, required this.api, required this.baseUrl});

  @override
  State<DetailPenjualanSheet> createState() => _DetailPenjualanSheetState();
}

class _DetailPenjualanSheetState extends State<DetailPenjualanSheet> {
  List<DetailPenjualan> details = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      final res = await widget.api.get('${widget.baseUrl}/api_detail_penjualan.php?id=${widget.penjualan.id}');
      final text = res.body;
      if (text.startsWith('<')) {
        throw Exception("PHP Error: Harap ubah mysqli_stmt_get_result di api_detail_penjualan.php!");
      }
      final decoded = jsonDecode(text);
      if (decoded['status'] == true) {
        final List data = decoded['data'];
        setState(() {
          details = data.map((e) => DetailPenjualan.fromJson(e)).toList();
          loading = false;
        });
      } else {
        throw Exception(decoded['message'] ?? 'Error fetching detail');
      }
    } catch (e) {
      debugPrint("DETAIL ERROR: $e");
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Detail Order #${widget.penjualan.id}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Text("Tanggal: ${widget.penjualan.tanggal}", style: const TextStyle(color: Colors.grey)),
          const Divider(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : details.isEmpty
                    ? const Center(child: Text("Detail tidak ditemukan"))
                    : ListView.builder(
                        itemCount: details.length,
                        itemBuilder: (ctx, i) {
                          final d = details[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(d.namaProduk),
                            subtitle: Text("${d.qty} x Rp ${d.harga.toStringAsFixed(0)}"),
                            trailing: Text("Rp ${d.subtotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Transaksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text("Rp ${widget.penjualan.total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
