import 'dart:convert';
import 'dart:html' as html; // para download CSV (Flutter Web)
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_select_flutter/multi_select_flutter.dart';

void main() {
  runApp(const MyApp());
}

// >>> AJUSTE AQUI SE PRECISAR <<<
const API_URL =
    'https://script.google.com/macros/s/AKfycbwBX8ZkThfg8kQwVmKyJt1leb2CXkMty8iOwQmilZn6xCGKY-cKccaHo_VYobW-uDpAZg/exec';
const API_KEY = 's123g456m789';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue);
    const darkText = Color(0xFF1A1A1A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Gestão de Parcerias - Aginova - UFMS',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textTheme: base.textTheme.apply(
          bodyColor: darkText,
          displayColor: darkText,
        ),
        chipTheme: base.chipTheme.copyWith(
          side: const BorderSide(color: Colors.transparent),
          labelStyle: const TextStyle(color: darkText),
          backgroundColor: Colors.blue.shade50,
        ),
        dialogTheme: base.dialogTheme.copyWith(
          titleTextStyle: const TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(color: darkText),
        ),
        checkboxTheme: base.checkboxTheme.copyWith(
          side: const BorderSide(color: Colors.black45),
        ),
      ),
      home: const DemandasHome(),
    );
  }
}

class DemandasHome extends StatefulWidget {
  const DemandasHome({super.key});
  @override
  State<DemandasHome> createState() => _DemandasHomeState();
}

class _DemandasHomeState extends State<DemandasHome> {
  // Dados / paginação
  final List<Demanda> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 30;
  int _totalCount = 0;

  // Busca/filtros
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showFilters = false;
  bool _selectMode = false; // <- modo Seleção de Texto
  Filtros f = Filtros();

  // Opções dos filtros (via diag=1)
  late Future<Opcoes> _optsFut;
  Opcoes _opts = const Opcoes();

  @override
  void initState() {
    super.initState();
    _optsFut = _loadOpts();
    _reload(reset: true);
  }

  // ---------------- HTTP ----------------
  Uri _buildUri({int? pageOverride}) {
    final q = <String, String>{
      'key': API_KEY,
      'page': (pageOverride ?? _page).toString(),
      'pageSize': _pageSize.toString(),
      'orderBy': 'ultima_atualizacao_status',
      'orderDir': 'desc',
    };

    final s = _searchCtrl.text.trim();
    if (s.isNotEmpty) q['q'] = s;

    if (f.tipos.isNotEmpty) q['tipo_in'] = f.tipos.join(',');
    if (f.instrumentos.isNotEmpty) {
      q['instrumento_juridico_in'] = f.instrumentos.join(',');
    }
    if (f.unidades.isNotEmpty) q['unidade_in'] = f.unidades.join(',');
    if (f.statuses.isNotEmpty) q['status_in'] = f.statuses.join(',');
    if (f.coordenadores.isNotEmpty) q['coordenador_in'] = f.coordenadores.join(',');
    if (f.servidores.isNotEmpty) {
      q['servidor_responsavel_in'] = f.servidores.join(',');
    }
    if (f.parceiros.isNotEmpty) {
      q['instituicao_parceira_in'] = f.parceiros.join(',');
    }

    return Uri.parse(API_URL).replace(queryParameters: q);
  }

  Future<void> _reload({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
        _totalCount = 0;
      }
      if (!_hasMore) return;

      final uri = _buildUri();
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final obj = json.decode(resp.body) as Map<String, dynamic>;
        final List data = (obj['data'] ?? []) as List;
        final newItems = data.map((e) => Demanda.fromJson(Map<String, dynamic>.from(e))).toList();
        _items.addAll(newItems);
        final count = (obj['count'] ?? 0) as int;
        final totalLoaded = _items.length;
        setState(() {
          _totalCount = count;
          _hasMore = totalLoaded < count;
          if (_hasMore) _page += 1;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    await _reload(reset: false);
  }

  Future<Opcoes> _loadOpts() async {
    final uri = Uri.parse(API_URL).replace(queryParameters: {
      'key': API_KEY,
      'diag': '1',
    });
    final r = await http.get(uri);
    if (r.statusCode == 200) {
      final m = json.decode(r.body);
      final o = Opcoes.fromDiagJson(m['opts'] ?? {});
      setState(() => _opts = o);
      return o;
    }
    return const Opcoes();
  }

  // ---------------- EXPORT CSV ----------------
  Future<void> _exportCsv() async {
    final header = [
      'Carimbo de data/hora',
      'Endereço de e-mail',
      'Servidor responsável',
      'Coordenador',
      'Novo, Aditivo ou Apostilamento',
      'Instrumento jurídico',
      'Unidade',
      'Instituição parceira',
      'Descrição do objeto/projeto',
      'Vigência (meses)',
      'Valor (R\$)',
      'Processo SEI',
      'Nº do Processo SEI',
      'Observações',
      'Status',
      'Última atualização de status',
      'Usuário',
      'Validado?',
      'Prioridade',
      'Validado por',
      'Validado em',
      'ID',
    ];

    int page = 1;
    const int pageSize = 500;
    final rows = <List<String>>[];
    int fetched = 0;
    int total = 0;

    while (true) {
      final qp = <String, String>{
        'key': API_KEY,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'orderBy': 'ultima_atualizacao_status',
        'orderDir': 'desc',
      };

      final s = _searchCtrl.text.trim();
      if (s.isNotEmpty) qp['q'] = s;
      if (f.tipos.isNotEmpty) qp['tipo_in'] = f.tipos.join(',');
      if (f.instrumentos.isNotEmpty) qp['instrumento_juridico_in'] = f.instrumentos.join(',');
      if (f.unidades.isNotEmpty) qp['unidade_in'] = f.unidades.join(',');
      if (f.statuses.isNotEmpty) qp['status_in'] = f.statuses.join(',');
      if (f.coordenadores.isNotEmpty) qp['coordenador_in'] = f.coordenadores.join(',');
      if (f.servidores.isNotEmpty) qp['servidor_responsavel_in'] = f.servidores.join(',');
      if (f.parceiros.isNotEmpty) qp['instituicao_parceira_in'] = f.parceiros.join(',');

      final uri = Uri.parse(API_URL).replace(queryParameters: qp);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) break;

      final obj = json.decode(resp.body) as Map<String, dynamic>;
      final List data = (obj['data'] ?? []) as List;
      total = (obj['count'] ?? 0) as int;

      for (final e in data) {
        final d = Demanda.fromJson(Map<String, dynamic>.from(e));
        rows.add([
          _s(d.carimbo),
          _s(d.email),
          _s(d.servidorResponsavel),
          _s(d.coordenador),
          _s(d.tipo),
          _s(d.instrumentoJuridico),
          _s(d.unidade),
          _s(d.instituicaoParceira),
          _s(d.descricao),
          d.vigenciaMeses?.toString() ?? '',
          d.valor?.toString() ?? '',
          _s(d.processoSei),
          _s(d.numeroProcessoSei),
          _s(d.observacoes),
          _s(d.status),
          _s(d.ultimaAtualizacao),
          _s(d.usuario),
          d.validado == null ? '' : (d.validado! ? 'Sim' : 'Não'),
          d.prioridade?.toString() ?? '',
          _s(d.validadoPor),
          _s(d.validadoEm),
          _s(d.id),
        ]);
      }

      fetched += data.length;
      if (fetched >= total || data.isEmpty) break;
      page += 1;
    }

    final sb = StringBuffer();
    sb.writeln(header.map(_csvEscape).join(','));
    for (final r in rows) {
      sb.writeln(r.map(_csvEscape).join(','));
    }
    final bytes = utf8.encode(sb.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'demandas_export.csv'
      ..style.display = 'none';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _csvEscape(String s) => '"${s.replaceAll('"', '""')}"';
  static String _s(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return v.toIso8601String();
    return v.toString();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Gestão de Parcerias - Aginova - UFMS'),
        actions: [
          IconButton(
            tooltip: _showFilters ? 'Ocultar filtros' : 'Mostrar filtros',
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
          ),
          IconButton(
            tooltip: _selectMode ? 'Desativar seleção de texto' : 'Ativar seleção de texto',
            onPressed: () => setState(() => _selectMode = !_selectMode),
            icon: Icon(_selectMode ? Icons.text_fields : Icons.select_all),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Recarregar',
            onPressed: () => _reload(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Painel de filtros colapsável
          FutureBuilder<Opcoes>(
            future: _optsFut,
            builder: (ctx, snap) {
              return AnimatedCrossFade(
                crossFadeState: _showFilters
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 180),
                firstChild: _buildFilters(context),
                secondChild: const SizedBox.shrink(),
              );
            },
          ),

          // Linha de busca + aplicar/limpar + contadores
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: 'Buscar (descrição, unidade, número do SEI...)',
                          prefixIcon: const Icon(Icons.search),
                          labelStyle: const TextStyle(color: Color(0xFF1A1A1A)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onSubmitted: (_) => _reload(reset: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _reload(reset: true),
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Aplicar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          f = Filtros();
                        });
                        _reload(reset: true);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Exibindo ${_items.length} de $_totalCount',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista (com ou sem modo de seleção)
          Expanded(
            child: _selectMode ? SelectionArea(child: _buildList()) : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    const dark = Color(0xFF1A1A1A);

    MultiSelectDialogField<String> multi(
      String label,
      List<String> options,
      List<String> selected,
      void Function(List<String>) onChanged,
    ) {
      final items = options.map((e) => MultiSelectItem<String>(e, e)).toList();
      return MultiSelectDialogField<String>(
        items: items,
        initialValue: selected,
        searchable: true,
        title: Text(label, style: const TextStyle(color: dark)),
        buttonText: Text(label, style: const TextStyle(color: dark)),
        buttonIcon: const Icon(Icons.arrow_drop_down, color: dark),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue.shade50,
        ),
        dialogWidth: 520,
        separateSelectedItems: true,
        chipDisplay: MultiSelectChipDisplay(
          textStyle: const TextStyle(color: dark),
          chipColor: Colors.blue.shade50,
          onTap: (v) {
            final nv = List<String>.from(selected)..remove(v);
            onChanged(nv);
            _reload(reset: true);
          },
        ),
        onConfirm: (vals) {
          onChanged(vals);
          _reload(reset: true);
        },
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: Colors.blue.shade50,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: multi('Tipo', _opts.tipo, f.tipos, (v) => setState(() => f.tipos = v)),
          ),
          SizedBox(
            width: 300,
            child: multi('Instrumento jurídico', _opts.instrumentoJuridico, f.instrumentos,
                (v) => setState(() => f.instrumentos = v)),
          ),
          SizedBox(
            width: 280,
            child: multi('Unidade', _opts.unidade, f.unidades, (v) => setState(() => f.unidades = v)),
          ),
          SizedBox(
            width: 260,
            child: multi('Status', _opts.status, f.statuses, (v) => setState(() => f.statuses = v)),
          ),
          SizedBox(
            width: 320,
            child: multi('Coordenador', _opts.coordenador, f.coordenadores,
                (v) => setState(() => f.coordenadores = v)),
          ),
          SizedBox(
            width: 320,
            child: multi('Servidor responsável', _opts.servidorResponsavel, f.servidores,
                (v) => setState(() => f.servidores = v)),
          ),
          SizedBox(
            width: 360,
            child: multi('Instituição parceira', _opts.instituicaoParceira, f.parceiros,
                (v) => setState(() => f.parceiros = v)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Sem resultados'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final d = _items[i];
          final stale = _isStale(d.ultimaAtualizacao);

          // Preferência de SEI: Nº do Processo > Processo SEI
          final sei = (d.numeroProcessoSei != null && d.numeroProcessoSei!.trim().isNotEmpty)
              ? d.numeroProcessoSei
              : (d.processoSei ?? '');

          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              title: Text(
                _short(d.descricao),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (_notEmpty(d.unidade)) _pill('Unidade', d.unidade),
                    if (_notEmpty(d.coordenador)) _pill('Coordenador', d.coordenador),
                    if (_notEmpty(d.instrumentoJuridico)) _pill('Instrumento', d.instrumentoJuridico),
                    if (_notEmpty(d.tipo)) _pill('Tipo', d.tipo),
                    if (_notEmpty(sei)) _pill('SEI', sei),
                    if (_notEmpty(d.servidorResponsavel)) _pill('Servidor', d.servidorResponsavel),
                    if (_notEmpty(d.status)) _pill('Status', d.status),
                    _pill(
                      'Última atualização',
                      _fmtDate(d.ultimaAtualizacao),
                      danger: stale,
                    ),
                  ],
                ),
              ),
              enabled: !_selectMode, // no modo seleção, desabilita clique
              onTap: _selectMode
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DemandaDetalhePage(d: d)),
                      );
                    },
              mouseCursor: _selectMode ? SystemMouseCursors.text : SystemMouseCursors.click,
            ),
          );
        },
      ),
    );
  }

  // Helpers de UI/texto
  String _short(String? s) {
    if (s == null || s.trim().isEmpty) return '(sem descrição)';
    return s.length <= 160 ? s : '${s.substring(0, 160)}…';
  }

  bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;

  bool _isStale(DateTime? dt) {
    if (dt == null) return false;
    final diff = DateTime.now().difference(dt);
    return diff > const Duration(days: 2);
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _pill(String label, String? value, {bool danger = false}) {
    final v = value ?? '';
    final text = '$label: $v';
    final bg = danger ? Colors.red.shade50 : Colors.blue.shade50;
    final bd = danger ? Colors.red.shade200 : Colors.blue.shade200;
    final fg = const Color(0xFF1A1A1A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bd),
      ),
      child: Text(text, style: TextStyle(color: fg)),
    );
  }
}

// ----------------- Modelos / filtros -----------------
class Filtros {
  List<String> tipos = [];
  List<String> instrumentos = [];
  List<String> unidades = [];
  List<String> statuses = [];
  List<String> coordenadores = [];
  List<String> servidores = [];
  List<String> parceiros = [];
}

class Demanda {
  final String? id;
  final String? descricao;
  final String? unidade;
  final String? status;
  final String? tipo;
  final String? instrumentoJuridico;
  final String? coordenador;
  final String? servidorResponsavel;
  final String? instituicaoParceira;
  final String? numeroProcessoSei;
  final String? processoSei;
  final DateTime? ultimaAtualizacao;
  final DateTime? carimbo;
  final int? vigenciaMeses;
  final num? valor;
  final String? observacoes;
  final String? email;
  final String? usuario;
  final bool? validado;
  final int? prioridade;
  final String? validadoPor;
  final DateTime? validadoEm;

  Demanda({
    this.id,
    this.descricao,
    this.unidade,
    this.status,
    this.tipo,
    this.instrumentoJuridico,
    this.coordenador,
    this.servidorResponsavel,
    this.instituicaoParceira,
    this.numeroProcessoSei,
    this.processoSei,
    this.ultimaAtualizacao,
    this.carimbo,
    this.vigenciaMeses,
    this.valor,
    this.observacoes,
    this.email,
    this.usuario,
    this.validado,
    this.prioridade,
    this.validadoPor,
    this.validadoEm,
  });

  factory Demanda.fromJson(Map<String, dynamic> m) {
    DateTime? _pd(v) {
      if (v == null || v.toString().trim().isEmpty) return null;
      return DateTime.tryParse(v.toString());
    }

    int? _pi(v) => v == null ? null : int.tryParse(v.toString());
    num? _pn(v) => v == null ? null : num.tryParse(v.toString());

    return Demanda(
      id: m['id']?.toString(),
      descricao: m['descricao']?.toString(),
      unidade: m['unidade']?.toString(),
      status: m['status']?.toString(),
      tipo: m['tipo']?.toString(),
      instrumentoJuridico: m['instrumento_juridico']?.toString(),
      coordenador: m['coordenador']?.toString(),
      servidorResponsavel: m['servidor_responsavel']?.toString(),
      instituicaoParceira: m['instituicao_parceira']?.toString(),
      numeroProcessoSei: m['numero_processo_sei']?.toString(),
      processoSei: m['processo_sei']?.toString(),
      ultimaAtualizacao: _pd(m['ultima_atualizacao_status']),
      carimbo: _pd(m['carimbo_data_hora']),
      vigenciaMeses: _pi(m['vigencia_meses']),
      valor: _pn(m['valor']),
      observacoes: m['observacoes']?.toString(),
      email: m['email']?.toString(),
      usuario: m['usuario']?.toString(),
      validado: (m['validado'] is bool)
          ? m['validado']
          : (m['validado']?.toString().toLowerCase() == 'true'),
      prioridade: _pi(m['prioridade']),
      validadoPor: m['validado_por']?.toString(),
      validadoEm: _pd(m['validado_em']),
    );
  }
}

class Opcoes {
  final List<String> tipo;
  final List<String> instrumentoJuridico;
  final List<String> unidade;
  final List<String> status;
  final List<String> coordenador;
  final List<String> servidorResponsavel;
  final List<String> instituicaoParceira;

  const Opcoes({
    this.tipo = const [],
    this.instrumentoJuridico = const [],
    this.unidade = const [],
    this.status = const [],
    this.coordenador = const [],
    this.servidorResponsavel = const [],
    this.instituicaoParceira = const [],
  });

  factory Opcoes.fromDiagJson(Map<String, dynamic> m) {
    List<String> _ls(String k) {
      final v = m[k];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return Opcoes(
      tipo: _ls('tipo'),
      instrumentoJuridico: _ls('instrumento_juridico'),
      unidade: _ls('unidade'),
      status: _ls('status'),
      coordenador: _ls('coordenador'),
      servidorResponsavel: _ls('servidor_responsavel'),
      instituicaoParceira: _ls('instituicao_parceira'),
    );
  }
}

// ----------------- Detalhe -----------------
class DemandaDetalhePage extends StatelessWidget {
  final Demanda d;
  const DemandaDetalhePage({super.key, required this.d});

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    }

  String _fmtMoney(num? v) {
    if (v == null) return '-';
    return 'R\$ ${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_KV>[
      _KV('Descrição', d.descricao),
      _KV('Unidade', d.unidade),
      _KV('Coordenador', d.coordenador),
      _KV('Instrumento jurídico', d.instrumentoJuridico),
      _KV('Tipo', d.tipo),
      _KV('Nº Processo SEI', d.numeroProcessoSei),
      _KV('Processo SEI', d.processoSei),
      _KV('Servidor responsável', d.servidorResponsavel),
      _KV('Status', d.status),
      _KV('Última atualização', _fmtDate(d.ultimaAtualizacao)),
      _KV('Vigência (meses)', d.vigenciaMeses?.toString()),
      _KV('Valor (R\$)', _fmtMoney(d.valor)),
      _KV('Observações', d.observacoes),
      _KV('Carimbo', _fmtDate(d.carimbo)),
      _KV('E-mail', d.email),
      _KV('Usuário', d.usuario),
      _KV('Validado?', d.validado == null ? '-' : (d.validado! ? 'Sim' : 'Não')),
      _KV('Prioridade', d.prioridade?.toString()),
      _KV('Validado por', d.validadoPor),
      _KV('Validado em', _fmtDate(d.validadoEm)),
      _KV('ID', d.id),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Demanda')),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows.map((kv) => _detailRow(kv.k, kv.v ?? '-')).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KV {
  final String k;
  final String? v;
  _KV(this.k, this.v);
}

