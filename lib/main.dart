import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
/* Para download no Web */
import 'dart:html' as html; // ok no Flutter Web; se for compilar mobile depois, podemos condicionar

// ====== CONFIG SUA API ======
const String kBaseUrl = 'https://script.google.com/macros/s/AKfycbwBX8ZkThfg8kQwVmKyJt1leb2CXkMty8iOwQmilZn6xCGKY-cKccaHo_VYobW-uDpAZg/exec';
const String kApiKey  = 's123g456m789';

// ====== MODELOS ======
class Demanda {
  final String id;
  final String? descricao, status, unidade, instituicaoParceira, instrumentoJuridico, tipo;
  final String? numeroProcessoSei, processoSei, observacoes, ultimaAtualizacao;
  final String? servidorResponsavel, coordenador, usuario, email, prioridade, validadoPor, validadoEm, carimboDataHora;
  final double? vigenciaMeses, valor;
  final bool? validado;

  Demanda({
    required this.id,
    this.descricao, this.status, this.unidade, this.instituicaoParceira, this.instrumentoJuridico, this.tipo,
    this.numeroProcessoSei, this.processoSei, this.observacoes, this.ultimaAtualizacao,
    this.servidorResponsavel, this.coordenador, this.usuario, this.email, this.prioridade, this.validadoPor, this.validadoEm, this.carimboDataHora,
    this.vigenciaMeses, this.valor, this.validado,
  });

  factory Demanda.fromJson(Map<String, dynamic> j) {
    double? toD(v)=>v==null?null:(v is num?v.toDouble():double.tryParse(v.toString()));
    bool? toB(v){ if(v==null)return null; final s=v.toString().toLowerCase(); if(s=='true')return true; if(s=='false')return false; return null; }
    return Demanda(
      id: j['id']?.toString()??'',
      descricao: j['descricao']?.toString(),
      status: j['status']?.toString(),
      unidade: j['unidade']?.toString(),
      instituicaoParceira: j['instituicao_parceira']?.toString(),
      instrumentoJuridico: j['instrumento_juridico']?.toString(),
      tipo: j['tipo']?.toString(),
      numeroProcessoSei: j['numero_processo_sei']?.toString(),
      processoSei: j['processo_sei']?.toString(),
      observacoes: j['observacoes']?.toString(),
      ultimaAtualizacao: j['ultima_atualizacao_status']?.toString(),
      servidorResponsavel: j['servidor_responsavel']?.toString(),
      coordenador: j['coordenador']?.toString(),
      usuario: j['usuario']?.toString(),
      email: j['email']?.toString(),
      prioridade: j['prioridade']?.toString(),
      validadoPor: j['validado_por']?.toString(),
      validadoEm: j['validado_em']?.toString(),
      carimboDataHora: j['carimbo_data_hora']?.toString(),
      vigenciaMeses: toD(j['vigencia_meses']),
      valor: toD(j['valor']),
      validado: toB(j['validado']),
    );
  }
}

class ApiResponse {
  final int count, page, pageSize;
  final List<Demanda> data;
  ApiResponse({required this.count, required this.page, required this.pageSize, required this.data});
  factory ApiResponse.fromJson(Map<String,dynamic> j){
    final list=(j['data'] as List).map((e)=>Demanda.fromJson(e)).toList();
    return ApiResponse(count:j['count']??list.length,page:j['page']??1,pageSize:j['pageSize']??list.length,data:list);
  }
}

class MetaOptions {
  final List<String> status, tipo, instrumento, unidade, coordenador, servidor, instituicao, usuario, prioridade;
  MetaOptions({
    required this.status, required this.tipo, required this.instrumento, required this.unidade,
    required this.coordenador, required this.servidor, required this.instituicao, required this.usuario, required this.prioridade
  });
  factory MetaOptions.fromJson(Map<String,dynamic> j){
    List<String> list(String k)=> ((j['options']?[k] as List?)??[]).map((e)=>e.toString()).toList();
    return MetaOptions(
      status: list('status'),
      tipo: list('tipo'),
      instrumento: list('instrumento_juridico'),
      unidade: list('unidade'),
      coordenador: list('coordenador'),
      servidor: list('servidor_responsavel'),
      instituicao: list('instituicao_parceira'),
      usuario: list('usuario'),
      prioridade: list('prioridade'),
    );
  }
}

// ====== FILTROS ======
class FilterData {
  // Texto simples
  String q='', email='', descricao='', processoSei='', numeroSei='', observacoes='', validadoPor='', carimboContains='', validadoEmContains='';
  // Numéricos e data-range
  double? valorMin, valorMax, vigenciaMin, vigenciaMax;
  DateTime? attMin, attMax;
  // Boolean
  String? validado; // "true" | "false" | null
  // MULTI-SELEÇÃO
  final List<String> status = [];
  final List<String> unidade = [];
  final List<String> tipo = [];
  final List<String> instrumento = [];
  final List<String> coordenador = [];
  final List<String> servidor = [];
  final List<String> instituicao = [];
  final List<String> usuario = [];
  final List<String> prioridade = [];

  Map<String,String> toQuery(){
    String? joinOr(List<String> xs){ if(xs.isEmpty) return null; return xs.join('|'); }
    final m=<String,String>{
      if(q.isNotEmpty) 'q':q,
      if(email.isNotEmpty) 'email':email,
      if(descricao.isNotEmpty) 'descricao':descricao,
      if(processoSei.isNotEmpty) 'processo_sei':processoSei,
      if(numeroSei.isNotEmpty) 'numero_processo_sei':numeroSei,
      if(observacoes.isNotEmpty) 'observacoes':observacoes,
      if(validadoPor.isNotEmpty) 'validado_por':validadoPor,
      if(carimboContains.isNotEmpty) 'carimbo_data_hora':carimboContains,
      if(validadoEmContains.isNotEmpty) 'validado_em':validadoEmContains,
      if(validado!=null && validado!.isNotEmpty) 'validado':validado!,
      if(valorMin!=null) 'valor_min':'${valorMin!}',
      if(valorMax!=null) 'valor_max':'${valorMax!}',
      if(vigenciaMin!=null) 'vigencia_min':'${vigenciaMin!}',
      if(vigenciaMax!=null) 'vigencia_max':'${vigenciaMax!}',
      if(attMin!=null) 'atualizacao_min':DateFormat('yyyy-MM-dd').format(attMin!),
      if(attMax!=null) 'atualizacao_max':DateFormat('yyyy-MM-dd').format(attMax!),
      if(joinOr(status)!=null) 'status': joinOr(status)!,
      if(joinOr(unidade)!=null) 'unidade': joinOr(unidade)!,
      if(joinOr(tipo)!=null) 'tipo': joinOr(tipo)!,
      if(joinOr(instrumento)!=null) 'instrumento_juridico': joinOr(instrumento)!,
      if(joinOr(coordenador)!=null) 'coordenador': joinOr(coordenador)!,
      if(joinOr(servidor)!=null) 'servidor_responsavel': joinOr(servidor)!,
      if(joinOr(instituicao)!=null) 'instituicao_parceira': joinOr(instituicao)!,
      if(joinOr(usuario)!=null) 'usuario': joinOr(usuario)!,
      if(joinOr(prioridade)!=null) 'prioridade': joinOr(prioridade)!,
    };
    return m;
  }

  void clear(){
    q=''; email=''; descricao=''; processoSei=''; numeroSei=''; observacoes=''; validadoPor='';
    carimboContains=''; validadoEmContains='';
    valorMin=null; valorMax=null; vigenciaMin=null; vigenciaMax=null; attMin=null; attMax=null; validado=null;
    status.clear(); unidade.clear(); tipo.clear(); instrumento.clear(); coordenador.clear(); servidor.clear(); instituicao.clear(); usuario.clear(); prioridade.clear();
  }
}

// ====== API ======
class DemandsApi {
  final String baseUrl, apiKey;
  DemandsApi({required this.baseUrl, required this.apiKey});

  Future<ApiResponse> fetch({
    required FilterData filters,
    int page=1,
    int pageSize=50,
    String orderBy='ultima_atualizacao_status',
    String orderDir='desc'
  }) async {
    final params={
      'key':apiKey,
      'page':'$page',
      'pageSize':'$pageSize',
      'orderBy':orderBy,
      'orderDir':orderDir,
      ...filters.toQuery()
    };
    final uri=Uri.parse(baseUrl).replace(queryParameters: params);
    final r=await http.get(uri);
    if(r.statusCode!=200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    final m=json.decode(r.body) as Map<String,dynamic>;
    if(m.containsKey('error')) throw Exception('API error: ${m['error']}');
    return ApiResponse.fromJson(m);
  }

  Future<MetaOptions> fetchMeta() async {
    final uri=Uri.parse(baseUrl).replace(queryParameters:{'key':apiKey,'meta':'1'});
    final r=await http.get(uri);
    if(r.statusCode!=200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return MetaOptions.fromJson(json.decode(r.body) as Map<String,dynamic>);
  }
}

// ====== APP ======
void main(){ runApp(const DemandasApp()); }

class DemandasApp extends StatelessWidget {
  const DemandasApp({super.key});
  @override Widget build(BuildContext context){
    return MaterialApp(
      title:'Gestão de Demandas',
      theme: ThemeData(
        useMaterial3:true,
        colorSchemeSeed: Colors.blue, // tons de azul
        brightness: Brightness.light,
      ),
      home: const DemandasHome(),
    );
  }
}

class DemandasHome extends StatefulWidget { const DemandasHome({super.key}); @override State<DemandasHome> createState()=>_DemandasHomeState(); }

class _DemandasHomeState extends State<DemandasHome> {
  final api=DemandsApi(baseUrl:kBaseUrl, apiKey:kApiKey);
  final f=FilterData();
  MetaOptions? meta;

  // Lista + paginação infinita
  final List<Demanda> _items = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 50;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _sc = ScrollController();

  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try { final m = await api.fetchMeta(); setState(()=> meta = m); } catch(_) {}
      await _reloadFirstPage();
    });
    _sc.addListener(_onScroll);
  }

  @override void dispose(){
    _sc.dispose();
    super.dispose();
  }

  Future<void> _reloadFirstPage() async {
    setState((){ _isLoading=true; _page=1; _hasMore=true; _items.clear(); _total=0; });
    try {
      final r = await api.fetch(filters:f, page:_page, pageSize:_pageSize);
      setState(() {
        _items.addAll(r.data);
        _total = r.count;
        _hasMore = _items.length < _total;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
    } finally {
      if (mounted) setState(()=> _isLoading=false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(()=> _isLoading=true);
    try {
      final next = _page + 1;
      final r = await api.fetch(filters:f, page:next, pageSize:_pageSize);
      setState(() {
        _page = next;
        _items.addAll(r.data);
        _total = r.count;
        _hasMore = _items.length < _total;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar mais: $e')));
    } finally {
      if (mounted) setState(()=> _isLoading=false);
    }
  }

  void _onScroll(){
    if (!_sc.hasClients || _isLoading || !_hasMore) return;
    final pos = _sc.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) { // a 300px do fim
      _loadMore();
    }
  }

  void _openFilters(){
    showModalBottomSheet(context:context, isScrollControlled:true, showDragHandle:true, builder:(ctx){
      final pad=MediaQuery.of(ctx).viewInsets+const EdgeInsets.all(16);
      final m=meta;
      return Padding(padding:pad, child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        const Text('Filtros', style: TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
        const SizedBox(height:8),
        _text('Busca livre (q)', f.q, (v){ f.q=v; }),
        _text('Endereço de e-mail', f.email, (v){ f.email=v; }),
        _multi('Servidor responsável', f.servidor, m?.servidor ?? const []),
        _multi('Coordenador', f.coordenador, m?.coordenador ?? const []),
        _multi('Tipo (Novo/Aditivo/Apostilamento)', f.tipo, m?.tipo ?? const []),
        _multi('Instrumento jurídico', f.instrumento, m?.instrumento ?? const []),
        _multi('Unidade', f.unidade, m?.unidade ?? const []),
        _multi('Instituição parceira', f.instituicao, m?.instituicao ?? const []),
        _text('Descrição do objeto/projeto', f.descricao, (v){ f.descricao=v; }),
        Row(children:[
          Expanded(child:_num('Vigência (meses) Mín', f.vigenciaMin, (v){ f.vigenciaMin=v; })),
          const SizedBox(width:8),
          Expanded(child:_num('Vigência (meses) Máx', f.vigenciaMax, (v){ f.vigenciaMax=v; })),
        ]),
        Row(children:[
          Expanded(child:_num('Valor (R\\\$) Mín', f.valorMin, (v){ f.valorMin=v; })),
          const SizedBox(width:8),
          Expanded(child:_num('Valor (R\\\$) Máx', f.valorMax, (v){ f.valorMax=v; })),
        ]),
        _text('Processo SEI', f.processoSei, (v){ f.processoSei=v; }),
        _text('Nº do Processo SEI', f.numeroSei, (v){ f.numeroSei=v; }),
        _text('Observações', f.observacoes, (v){ f.observacoes=v; }),
        _multi('Status', f.status, m?.status ?? const []),
        Row(children:[
          Expanded(child:_dateField(context,'Atualização mín (YYYY-MM-DD)', f.attMin, ()=>_pickDate(context,isMin:true))),
          const SizedBox(width:8),
          Expanded(child:_dateField(context,'Atualização máx (YYYY-MM-DD)', f.attMax, ()=>_pickDate(context,isMin:false))),
        ]),
        _multi('Usuário', f.usuario, m?.usuario ?? const []),
        _dropdown('Validado?', f.validado ?? '', ['','true','false'], (v){ f.validado = v.isEmpty? null : v; }),
        _multi('Prioridade', f.prioridade, m?.prioridade ?? const []),
        _text('Validado por', f.validadoPor, (v){ f.validadoPor=v; }),
        _text('Carimbo de data/hora (contém)', f.carimboContains, (v){ f.carimboContains=v; }),
        _text('Validado em (contém)', f.validadoEmContains, (v){ f.validadoEmContains=v; }),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: OutlinedButton(onPressed:() async { f.clear(); Navigator.pop(context); await _reloadFirstPage(); }, child: const Text('Limpar'))),
          const SizedBox(width:8),
          Expanded(child: FilledButton(onPressed:() async { Navigator.pop(context); await _reloadFirstPage(); }, child: const Text('Aplicar'))),
        ]),
        const SizedBox(height:8),
      ])));
    });
  }

  Future<void> _pickDate(BuildContext ctx,{required bool isMin}) async {
    final now=DateTime.now(); final initial=isMin?(f.attMin??now):(f.attMax??now);
    final picked=await showDatePicker(context:ctx, initialDate:initial, firstDate:DateTime(2000,1,1), lastDate:DateTime(2100,12,31));
    if(picked!=null) setState(()=> isMin? f.attMin=picked : f.attMax=picked);
  }

  Future<void> _exportCsv() async {
    try {
      // Baixar todas as páginas com os filtros atuais
      int page=1;
      final int pageSize=200; // você pode ajustar
      final List<Demanda> all = [];
      while (true) {
        final r = await api.fetch(filters:f, page:page, pageSize:pageSize);
        all.addAll(r.data);
        if (all.length >= r.count || r.data.isEmpty) break;
        page++;
      }

      // Monta CSV
      final headers = [
        'Carimbo de data/hora','Endereço de e-mail','Servidor responsável','Coordenador','Novo/Aditivo/Apostilamento',
        'Instrumento jurídico','Unidade','Instituição parceira','Descrição do objeto/projeto','Vigência (meses)',
        'Valor (R\$)','Processo SEI','Nº do Processo SEI','Observações','Status','Última atualização de status',
        'Usuário','Validado?','Prioridade','Validado por','Validado em','ID'
      ];

      String esc(String? s){
        final v = (s??'').replaceAll('"','""');
        return '"$v"';
      }
      String escNum(num? n){ return n==null? '': n.toString(); }
      String escBool(bool? b){ if(b==null) return ''; return b? 'true':'false'; }

      final buf = StringBuffer();
      buf.writeln(headers.join(','));
      for (final d in all) {
        buf.writeln([
          esc(d.carimboDataHora),
          esc(d.email),
          esc(d.servidorResponsavel),
          esc(d.coordenador),
          esc(d.tipo),
          esc(d.instrumentoJuridico),
          esc(d.unidade),
          esc(d.instituicaoParceira),
          esc(d.descricao),
          escNum(d.vigenciaMeses),
          escNum(d.valor),
          esc(d.processoSei),
          esc(d.numeroProcessoSei),
          esc(d.observacoes),
          esc(d.status),
          esc(d.ultimaAtualizacao),
          esc(d.usuario),
          escBool(d.validado),
          esc(d.prioridade),
          esc(d.validadoPor),
          esc(d.validadoEm),
          esc(d.id),
        ].join(','));
      }

      final bytes = utf8.encode(buf.toString());
      final b64 = base64Encode(bytes);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'demandas_${ts}.csv';

      if (kIsWeb) {
        final url = 'data:text/csv;base64,$b64';
        final anchor = html.AnchorElement(href: url)..setAttribute('download', fileName)..click();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportar CSV está disponível no Flutter Web.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao exportar CSV: $e')));
      }
    }
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Gestão de Parcerias - Aginova - UFMS'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _reloadFirstPage,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de status
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _isLoading && _items.isEmpty
                ? 'Carregando...'
                : 'Exibindo ${_items.length} de $_total registros',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
          Expanded(
            child: _items.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                ? const Center(child: Text('Sem resultados'))
                : ListView.separated(
                    controller: _sc,
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        // Loader de paginação infinita
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final d = _items[i];
                      return ListTile(
                        tileColor: i.isEven ? Colors.blue.shade50.withOpacity(0.2) : null,
                        title: Text(
                          d.descricao?.isNotEmpty==true ? d.descricao! : '(sem descrição)',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text([
                          if(d.status!=null) 'Status: ${d.status}',
                          if(d.unidade!=null) 'Unidade: ${d.unidade}',
                          if(d.valor!=null) 'Valor: ${_formatBRL(d.valor!)}',
                        ].join('  •  ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=>DetalhePage(demanda:d))),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade600,
        onPressed:_openFilters, icon: const Icon(Icons.filter_alt), label: const Text('Filtrar'),
      ),
    );
  }

  // ----- widgets auxiliares -----
  Widget _text(String label, String value, void Function(String) onChanged){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:6),
      child: TextField(
        decoration: InputDecoration(labelText:label, border: const OutlineInputBorder()),
        controller: TextEditingController(text:value)..selection=TextSelection.collapsed(offset:value.length),
        onChanged:onChanged
      ),
    );
  }

  Widget _num(String label, double? value, void Function(double?) onChanged){
    final c=TextEditingController(text:value==null?'':value.toString());
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal:true),
      decoration: InputDecoration(labelText:label, border: const OutlineInputBorder()),
      controller:c,
      onChanged:(v){ if(v.trim().isEmpty){ onChanged(null);} else { onChanged(double.tryParse(v.replaceAll(',', '.'))); }}
    );
  }

  Widget _dropdown(String label, String current, List<String> items, void Function(String) onChanged){
    final opts=[...items];
    if(opts.isEmpty || opts.first!='') opts.insert(0,''); // '(Todos)'
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:6),
      child: DropdownButtonFormField<String>(
        value: opts.contains(current)? current : '',
        items: opts.map((e)=>DropdownMenuItem(value:e, child: Text(e.isEmpty? '(Todos)' : e))).toList(),
        onChanged:(v){ onChanged(v??''); },
        decoration: InputDecoration(labelText:label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _multi(String label, List<String> selected, List<String> options){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 6, runSpacing: -8,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if(selected.isNotEmpty)
              ...selected.map((s)=> Chip(label: Text(s), onDeleted: (){ setState(()=> selected.remove(s)); })),
          ],
        ),
        const SizedBox(height:6),
        FilledButton.tonal(
          onPressed: () async {
            final newSel = await showDialog<List<String>>(
              context: context,
              builder: (ctx){
                final tmp = Set<String>.from(selected);
                final sorted = [...options]..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
                return AlertDialog(
                  title: Text(label),
                  content: SizedBox(width: 420, height: 420, child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (_,i){
                      final opt = sorted[i];
                      final checked = tmp.contains(opt);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(opt),
                        onChanged: (v){ if(v==true) { tmp.add(opt);} else { tmp.remove(opt);} (ctx as Element).markNeedsBuild(); },
                      );
                    },
                  )),
                  actions: [
                    TextButton(onPressed: ()=> Navigator.pop(ctx, selected), child: const Text('Cancelar')),
                    FilledButton(onPressed: ()=> Navigator.pop(ctx, tmp.toList()), child: const Text('Aplicar')),
                  ],
                );
              }
            );
            if(newSel!=null){ setState(()=> { selected..clear()..addAll(newSel) }); }
          },
          child: const Text('Selecionar...'),
        ),
      ]),
    );
  }

  Widget _dateField(BuildContext ctx, String label, DateTime? value, VoidCallback onPick){
    final text=value==null?'':DateFormat('yyyy-MM-dd').format(value);
    return TextField(readOnly:true, controller: TextEditingController(text:text), decoration: InputDecoration(labelText:label, border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed:onPick, icon: const Icon(Icons.date_range))), onTap:onPick);
  }
}

class DetalhePage extends StatelessWidget {
  final Demanda demanda;
  const DetalhePage({super.key, required this.demanda});
  @override Widget build(BuildContext context){
    String fmtDate(String? iso){ if(iso==null||iso.isEmpty)return '—'; try{ final dt=DateTime.parse(iso); return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal()); }catch(_){ return iso; } }
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes')),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        _tile('Descrição', demanda.descricao),
        _tile('Status', demanda.status),
        _tile('Unidade', demanda.unidade),
        _tile('Instituição parceira', demanda.instituicaoParceira),
        _tile('Instrumento jurídico', demanda.instrumentoJuridico),
        _tile('Tipo', demanda.tipo),
        _tile('Nº Processo SEI', demanda.numeroProcessoSei),
        _tile('Processo SEI', demanda.processoSei),
        _tile('Vigência (meses)', demanda.vigenciaMeses?.toStringAsFixed(0)),
        _tile('Valor', demanda.valor!=null? _formatBRL(demanda.valor!) : null),
        _tile('Última atualização', fmtDate(demanda.ultimaAtualizacao)),
        _tile('Servidor responsável', demanda.servidorResponsavel),
        _tile('Coordenador', demanda.coordenador),
        _tile('Usuário', demanda.usuario),
        _tile('E-mail', demanda.email),
        _tile('Prioridade', demanda.prioridade),
        _tile('Validado?', demanda.validado==null? '—' : (demanda.validado!?'Sim':'Não')),
        _tile('Validado por', demanda.validadoPor),
        _tile('Validado em', demanda.validadoEm),
        _tile('Carimbo de data/hora', demanda.carimboDataHora),
        _tile('Observações', demanda.observacoes),
        _tile('ID', demanda.id),
      ]),
    );
  }
  Widget _tile(String label, String? value){ return ListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(value?.isNotEmpty==true? value! : '—')); }
}

String _formatBRL(double v){ final f=NumberFormat.simpleCurrency(locale:'pt_BR'); return f.format(v); }

