# Achados da etapa 2 (testes)

Escopo: os 15 arquivos de `matlab/tests/` (81 funções `test_*`, contadas com `grep -c "function test_"`).
Todas as duplicações foram conferidas com `grep -rn` em `matlab/tests/` e no código testado. Só auditoria:
nenhum `.m` foi alterado e o MATLAB não foi rodado.

Conclusão geral: os testes já estão enxutos. Cada teste prova uma propriedade física ou um contrato
diferente, e os comentários explicam de onde vem o valor esperado. Os achados abaixo são poucos e
pequenos; os de número 3 e 4 são opcionais (a duplicação é real, mas a remoção troca uma checagem
local por uma referência cruzada a outro arquivo).

| # | Arquivo | Achado (com evidência) | Mudança proposta | Linhas (−) | Cobertura mantida por | Perturbação de prova | Decisão |
|---|---|---|---|---|---|---|---|
| 1 | `test_conversor.m:19-27, 80-85` | (c) `test_pout_igual_pin_menos_perdas` repete o teste de balanço no mesmo ponto (18 V, 7,7 A, mesmo `pc`). Como `equilibrio_conversor.m:58` define `Pout = (1-d)*iL*Vbat - Psw`, a identidade do teste (`Pout = Pin - Pcond - Psw`) é a mesma do balanço (`Pin = (1-d)*iL*Vbat + Pcond`, linha 24) mais a parcela `-Psw`. Os dois testes montam `eq = equilibrio_conversor(18, 7.7, pc)` do mesmo jeito. | Em `test_balanco_de_energia`: o comentário (linha 20) vira `% Potencia de entrada = potencia na bateria + perdas de conducao, e Pout = Pin - Pcond - Psw; eta fica entre 0,85 e 1.`; logo depois da linha 24 inserir `verifyEqual(tc, eq.Pout, v * i - eq.Pcond - eq.Psw, 'RelTol', 1e-9);`. Apagar o teste `test_pout_igual_pin_menos_perdas` inteiro (linhas 79-85, incluindo a linha em branco antes). As duas verificações ficam (são complementares: a 1ª pega erro em `d`/`iL`/`Pcond`, a 2ª pega erro no `-Psw` de `Pout`). | 4 (5 de código saem, 1 entra) | `test_balanco_de_energia` (as duas `verifyEqual`, mesmo ponto e mesma `RelTol` 1e-9) | Em `equilibrio_conversor.m:58` apagar `- eq.Psw`: o antigo `test_pout_igual_pin_menos_perdas` falha; o novo `test_balanco_de_energia` falha na linha inserida. (Também: em `:54` apagar `+ (1 - eq.d) * eq.iL * pc.VF` → as duas linhas falham, antes e depois.) | aprovado, aplicado |
| 2 | `test_conversor.m:6-9` | (d) `tc.TestData.p` não é lido por nenhum teste do arquivo (`grep -n "TestData\.p\b"` só acha as linhas 7-8 do próprio `setupOnce`; `test_dimensionamento` monta o seu `pz`). Só existe para montar `pc`. | `setupOnce` passa a ter uma linha de código: `tc.TestData.pc = parametros_conversor(parametros_painel('generico'), 12);` (com o comentário `% Conversor projetado para o painel generico e bateria de 12 V`). | 1 | Nada muda nos testes: o mesmo `pc` chega a todos | Em `equilibrio_conversor.m:51` trocar `ipv / eq.d` por `1.01 * ipv / eq.d`: `test_rhs_nulo_no_equilibrio` falha antes e depois (prova de que o `pc` compartilhado continua o mesmo e em uso). | aprovado, aplicado |
| 3 | `test_ztp160m_extracao.m:17, 20` | (b) As checagens de Pmp e Voc de STC do 2d repetem `test_ztp160m.m:17-18` com `m = 2`: `parametros_painel('ztp160m')` é exatamente `extrair_parametros(datasheet_painel('ztp160m'), '2d')` (`parametros_painel.m:13`), que é o `modelos{2}` de `validar_painel.m:15`; a curva é a mesma (`curva_pv(1000*ones, p.Tn, p, 2000)`, `validar_painel.m:24`), a referência é a mesma (`ds.Pmax`, `ds.Voc`) e a tolerância é a mesma (`RelTol 0.005` ≡ `abs(erro) < 0.005`). | Apagar as linhas 17 (`verifyEqual(tc, c25.Pmp, ds.Pmax, ...)`) e 20 (`verifyEqual(tc, c25.V(end), ds.Voc, ...)`). O comentário da linha 11 vira `% Confere que parametros_painel('ztp160m') reproduz Vmp, Isc e Kv do catalogo` e, logo abaixo, `% (Pmax e Voc de STC do 2d ja sao conferidos em test_ztp160m/test_pontos_de_stc, m = 2).` Vmp, Isc e Kv ficam (não estão em `validar_painel`). | 2 | `test_ztp160m.m:17-18` (laço `m = 1:2`, inclui o 2d) | Em `extrair_parametros.m:95` trocar `ds.Voc` por `1.01 * ds.Voc` (Voc do ajuste 1 % alto): a antiga linha 20 falha; `test_ztp160m.m:18` falha (m = 1 e 2). Em `:97` e `:99` trocar `ds.Imp` por `1.02 * ds.Imp`: a antiga linha 17 falha; `test_ztp160m.m:17` falha (erro de ~2,3 %). | Opcional. Decisão: recusado: o teste de extração fica autossuficiente |
| 4 | `test_ztp160m_extracao.m:29-30` | (b) A checagem de Pmax do 1d repete `test_ztp160m.m:17` com `m = 1`: `validar_painel.m:15` usa o mesmo `extrair_parametros(ds, '1d')`, a mesma curva de 2000 pontos e a mesma tolerância de 0,5 % contra `ds.Pmax`. Só `info.convergiu` (linha 28) não é coberto em outro lugar. | Apagar as linhas 29-30; na linha 27 trocar `[p1, info]` por `[~, info]`; o comentário da linha 25 vira `% Confere que o modelo de 1 diodo (a = 1,1) converge (residuo < 1e-6).` e, abaixo, `% (Pmax de STC do 1d ja e conferido em test_ztp160m/test_pontos_de_stc, m = 1).` | 2 | `test_ztp160m.m:17` (m = 1); a convergência continua na linha 28 | Em `extrair_parametros.m:97` e `:99` trocar `ds.Imp` por `1.02 * ds.Imp`: a antiga linha 30 falha; `test_ztp160m.m:17` (m = 1) falha. | Opcional. Decisão: recusado: o teste de extração fica autossuficiente |
| 5 | `test_quase_estatica.m:21-25, 72-79` | (a) O `setupOnce` monta o caso ZTP-160M (`pz`, `pcz`, `ctlz`, `config_mppt(pz)`) num struct `tc.TestData.ztp`, mas só um teste o usa (`grep -n "\.ztp\|z\."` só acha as linhas 25 e 72-79 de `test_energia_pso_janela_representativa`). O leitor precisa voltar ao `setupOnce` para saber que `z.p` é o ZTP-160M. `test_sim_dinamica.m:98-101` já monta o mesmo caso dentro do próprio teste. | Apagar as linhas 21-25 do `setupOnce` (comentário + 4 linhas). No teste: a linha 72 vira `d = tc.TestData;` seguida de `% Painel real (ZTP-160M), montado aqui porque so este teste o usa` e das 3 linhas `p = parametros_painel('ztp160m');`, `pc = parametros_conversor(p, 12);`, `ctl = projeto_pi(p, pc);`; a linha 73 usa `ctl.Ta`; a linha 76 vira `cfg = config_mppt(p);  cfg.seed = 1;`; as linhas 78-79 passam `ctl, p, pc` no lugar de `z.ctl, z.p, z.pc` (o `d.pt` fica). | 1 | O mesmo teste, com os mesmos parâmetros e a mesma `verifyEqual(..., 'RelTol', 0.01)` | Em `sim_quase_estatica.m:225` trocar `r.E = E;` por `r.E = 1.02 * E;`: a antiga e a nova `test_energia_pso_janela_representativa` falham (assim como os três `test_energia_igual_a_dinamica_*`). | aprovado, aplicado |

Total estimado: −10 linhas de código (−6 sem os opcionais 3 e 4); testes: 81 → 80.

## Pontos examinados e mantidos de propósito

- **Setup repetido entre arquivos** (`p`, `pc`, `ctl`, `pt`, `cfg` em `test_sim_dinamica.m:9-13` e `test_quase_estatica.m:8-20`; `p`/`pc` em `test_controle`, `test_linearizacao`, `test_chaveado_medio`): 2 a 5 linhas por arquivo. Uma função compartilhada esconderia de onde vem cada parâmetro (mesmo critério da etapa 1 para os experimentos).
- **`test_chaveado_medio.m:8-11` e `:28-31`**: as mesmas 4 linhas (painel, conversor, ponto de equilíbrio a 18 V) nos dois testes. Um `setupOnce` com 6 campos de `TestData` teria o mesmo tamanho e tiraria o ponto de operação de perto da conta que o usa.
- **`test_kcl_modulo.m:9` e `:21`, `test_sombreamento.m:59`**: `q = p; q.Nsub = 1; q.Ncel = p.Ns;` (1 linha). O 1º teste ainda zera `I0bp` com explicação própria; fica explícito.
- **`test_extracao.m:45` e `:70`**: as duas chamam `extrair_parametros(ds, '1d')`. Levar para o `setupOnce` pouparia 1 linha e afastaria o modelo 1d do teste que o compara com Villalva; não compensa.
- **`test_sombreamento.m:17-19` e `:31-33`**: as mesmas três curvas calculadas duas vezes, mas cada teste prova uma coisa (snapshot de Pmp/Vmp × número de picos). Juntar deixaria um teste com dois motivos para falhar.
- **`test_linearizacao.m:36`** (`height(c.picos) == 2` para `[1000 1000 400]`) repete `test_sombreamento.m:32`, mas aqui é pré-condição: garante que o laço seguinte passa pelos dois picos (com 3000 pontos, não 600). Sem ela o teste poderia passar vazio.
- **`test_termico.m:35` e `:43`**: a mesma temperatura de referência (1000 W/m², 1 m/s, sem Pel) nos dois testes; 1 linha cada, e cada teste prova um mecanismo físico diferente (vento × extração de eletricidade).
- **`test_conversor`**: `test_rhs_nulo_no_equilibrio` e `test_fechada_igual_fzero` se sobrepõem em (18; 7,7), mas o primeiro confere a consistência entre `conversor_medio_rhs` e `equilibrio_conversor` (código diferente) e o segundo a fórmula fechada em 4 pontos. `test_ponto_inviavel` e `test_sem_transferencia` cobrem ramos diferentes de `equilibrio_conversor.m` (`:44` e `:32`).
- **Testes "parecidos" em simuladores diferentes**: `test_oraculo_eficiencia_unitaria` existe em `test_sim_dinamica.m:36` e `test_quase_estatica.m:85`, e `nReinicios = NaN` é checado nos dois; cada um testa o seu simulador.
- **`test_sim_dinamica.m:21-22`**: `Pg >= c.Pmp - 1e-6` e `Pg ≈ c.Pmp (RelTol 1e-4)` não são redundantes: a 1ª prova que o oráculo refina além da grade de 3000 pontos, a 2ª limita o quanto.
- **`test_controle.m:52-57`**: `PMmin >= 45`, `GMmin >= 6`, `ts_max < 0,05` e `Ta >= 1,5 ts_max` são os critérios que `projeto_pi.m:147,169` impõe; parecem tautológicos, mas pegam quem mudar um limiar em `projeto_pi` (ex.: 45 → 40). `Kp > 0` (linha 54) é sempre verdade com `Kp = 1/abs(...)` (`projeto_pi.m:124`) e um `Kp` negativo já quebraria as margens no `setupOnce`; fica porque documenta a convenção de sinal em 1 linha.
- **`test_quase_estatica.m:214`** (`r5.V == r5.Vref`): é verdade por construção (`sim_quase_estatica.m:224`, `r.V = r.Vref`), mas é a única checagem do contrato documentado "r.V = r.Vref (PI assentado)". Fica.
- **`fprintf` de diagnóstico** (`test_quase_estatica.m:34-35, 80-81, 138-139, 156`, incluindo o `dPg` da linha 137, que só é impresso): registram os valores "Medido: ..." citados nos comentários e o contraste com segurar o início do bloco (comentário da linha 118). Não são código morto no sentido de afetar o resultado, e ajudam a revalidar os números. Ficam.
- **`[ctl, ~] = projeto_pi(...)`** (`test_quase_estatica.m:10,24`, `test_sim_dinamica.m:11,100`): equivale a `ctl = projeto_pi(...)` (`projeto_pi` não usa `nargout`). Ganho zero de linhas; mudança só cosmética, não proposta.
- **Observação (fora do escopo de simplificação)**: `test_controle.m:57` usa folga `- 1e-3` em `Ta >= 1,5 ts_max`; como `Ta = 1e-3*ceil(1,5 ts_max/1e-3)`, essa folga deixaria passar um `floor` no lugar do `ceil`. Apertar seria endurecer o teste, não simplificá-lo; fica registrado para decisão do usuário.
- **Observação**: o nome `test_fechada_igual_fzero` (`test_conversor.m:46`) cita `fzero`, que o teste não usa (o comentário explica que confere a equação original). Renomeado para `test_d_fechado_satisfaz_equilibrio` por decisão do usuário.

## Arquivos sem achados

- `test_cenarios.m`
- `test_chaveado_medio.m`
- `test_controle.m`
- `test_extracao.m`
- `test_kcl_modulo.m`
- `test_levenberg_marquardt.m`
- `test_linearizacao.m`
- `test_mppt.m`
- `test_sim_dinamica.m`
- `test_sombreamento.m`
- `test_termico.m`
- `test_ztp160m.m` (é a referência que cobre os achados 3 e 4; não muda)

## Verificação da aplicação (etapa 2)

- `test_fechada_igual_fzero` foi renomeado para `test_d_fechado_satisfaz_equilibrio` por decisão do usuário (só a linha `function`).
- Achado 1, perturbação: em `equilibrio_conversor.m:58` apagado `- eq.Psw`. Falhas: versão antiga 1 (`test_pout_igual_pin_menos_perdas`), versão nova 1 (`test_balanco_de_energia`, na verificação inserida).
- Achado 5, perturbação: em `sim_quase_estatica.m:225` `r.E = E;` virou `r.E = 1.02 * E;`. Falhas: antiga 4, nova 4 (`test_energia_pso_janela_representativa` falha nas duas versões).
- Achado 2 só remove um campo não lido; basta a suíte passar.
- As perturbações foram desfeitas com `git restore`; nenhum arquivo fora de `matlab/tests/` mudou.
- Suíte final: 80 testes, todos passando (`logs/testes_etapa2.log`).
