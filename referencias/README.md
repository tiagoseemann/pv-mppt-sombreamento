# Referências

Literatura de apoio ao trabalho, agrupada pelo bloco do modelo em que cada uma é usada.
As entradas BibTeX estão em [`referencias.bib`](referencias.bib) (mesmas chaves de
`proposta/proposta.tex`). Todos os DOIs foram conferidos no Crossref.

Os PDFs ficam em [`pdfs/`](pdfs/), nomeados pela chave (`villalva.pdf`, `femia.pdf`, ...).
A maioria é IEEE/Elsevier, com acesso pelo Periódicos CAPES (login CAFe da UFSC). Os PDFs
**não são versionados** (direitos autorais); só este índice e o `.bib` vão para o git.

**Já em `pdfs/`:** `villalva`, `villalvarep`, `femia`, `esram`, `patel`, `ishaquepso`,
`ishaquepso2`, `miyatake`, `liupso`, `anterior` (artigos IEEE baixados pela VPN da UFSC).

**Falta baixar à mão** (pela VPN; os sites pedem verificação anti-robô no navegador):
[`hussein`](https://doi.org/10.1049/ip-gtd:19951577) (IET),
[`ishaque`](https://www.sciencedirect.com/science/article/pii/S0927024810005477) e
[`skoplaki`](https://www.sciencedirect.com/science/article/pii/S0960148108001353) (ScienceDirect).
O manual `pinho` é gratuito no site do CRESESB (abrir pelo navegador). Livros (`barbi`,
`erickson`, `duffie`), norma (`en50530`) e datasheets não estão disponíveis como PDF aberto.

Legenda: **[P]** citada na proposta · **[C]** complementar, candidata ao relatório.

## Painel (modelo de 1 e 2 diodos, extração de parâmetros)

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `villalva` **[P]** | Villalva, Gazoli, Ruppert Filho. Comprehensive approach to modeling and simulation of photovoltaic arrays. *IEEE Trans. Power Electron.* 24(5):1198–1208, 2009. [doi:10.1109/TPEL.2009.2013862](https://doi.org/10.1109/TPEL.2009.2013862) | Modelo de 1 diodo e ajuste nos 3 pontos do datasheet. Tabela I com o **KC200GT**, usado como benchmark da extração (Tarefa 2) |
| `villalvarep` **[C]** | Villalva, Gazoli, Ruppert Filho. Modeling and circuit-based simulation of photovoltaic arrays. *Eletrônica de Potência* 14(1):35–45, 2009. [doi:10.18618/REP.2009.1.035045](https://doi.org/10.18618/REP.2009.1.035045) | Versão da SOBRAEP (acesso aberto, **PDF em `pdfs/villalvarep.pdf`**) com o mesmo método e o KC200GT. Substitui o artigo da TPEL enquanto ele não for baixado |
| `ishaque` **[P]** | Ishaque, Salam, Taheri. Simple, fast and accurate two-diode model for photovoltaic modules. *Sol. Energy Mater. Sol. Cells* 95(2):586–594, 2011. [doi:10.1016/j.solmat.2010.09.023](https://doi.org/10.1016/j.solmat.2010.09.023) | Modelo de 2 diodos e simplificações para a extração |

## Sombreamento parcial e diodos de bypass

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `patel` **[C]** | Patel, Agarwal. MATLAB-based modeling to study the effects of partial shading on PV array characteristics. *IEEE Trans. Energy Convers.* 23(1):302–310, 2008. [doi:10.1109/TEC.2007.914308](https://doi.org/10.1109/TEC.2007.914308) | Referência clássica de submódulos com irradiâncias diferentes + bypass e dos múltiplos picos na curva P-V |

## Modelo térmico

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `duffie` **[P]** | Duffie, Beckman. *Solar Engineering of Thermal Processes*. 4. ed. Wiley, 2013. | Balanço de energia do módulo e coeficientes de troca térmica |
| `skoplaki` **[C]** | Skoplaki, Palyvos. Operating temperature of photovoltaic modules: a survey of pertinent correlations. *Renew. Energy* 34(1):23–29, 2009. [doi:10.1016/j.renene.2008.04.009](https://doi.org/10.1016/j.renene.2008.04.009) | Correlações baseadas no NOCT, para comparar com a calibração de 1ª ordem |

## Conversor buck-boost (modelo médio, linearização, PI)

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `barbi` **[P]** | Barbi. *Modelagem de conversores CC-CC empregando modelo médio em espaço de estados*. Florianópolis: Ed. do Autor, 2015. | Modelo médio em espaço de estados |
| `erickson` **[P]** | Erickson, Maksimović. *Fundamentals of Power Electronics*. 2. ed. Springer, 2001. | Modelo médio com perdas, CCM/DCM, funções de transferência |

## MPPT local (P&O, Condutância Incremental)

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `femia` **[P]** | Femia, Petrone, Spagnuolo, Vitelli. Optimization of perturb and observe maximum power point tracking method. *IEEE Trans. Power Electron.* 20(4):963–973, 2005. [doi:10.1109/TPEL.2005.850975](https://doi.org/10.1109/TPEL.2005.850975) | Escolha do passo e do período do P&O a partir da dinâmica do conversor (Tarefa 8) |
| `hussein` **[P]** | Hussein, Muta, Hoshino, Osakada. Maximum photovoltaic power tracking: an algorithm for rapidly changing atmospheric conditions. *IEE Proc. Gener. Transm. Distrib.* 142(1):59–64, 1995. [doi:10.1049/ip-gtd:19951577](https://doi.org/10.1049/ip-gtd:19951577) | Algoritmo de Condutância Incremental |
| `esram` **[C]** | Esram, Chapman. Comparison of photovoltaic array maximum power point tracking techniques. *IEEE Trans. Energy Convers.* 22(2):439–449, 2007. [doi:10.1109/TEC.2006.874230](https://doi.org/10.1109/TEC.2006.874230) | Revisão de técnicas de MPPT, para a introdução e a justificativa da escolha dos algoritmos |

## MPPT global (PSO)

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `ishaquepso` **[P]** | Ishaque, Salam. A deterministic particle swarm optimization maximum power point tracker for photovoltaic system under partial shading condition. *IEEE Trans. Ind. Electron.* 60(8):3195–3206, 2013. [doi:10.1109/TIE.2012.2200223](https://doi.org/10.1109/TIE.2012.2200223) | PSO determinístico implementado em `mppt_pso` |
| `ishaquepso2` **[C]** | Ishaque, Salam, Amjad, Mekhilef. An improved particle swarm optimization (PSO)-based MPPT for PV with reduced steady-state oscillation. *IEEE Trans. Power Electron.* 27(8):3627–3638, 2012. [doi:10.1109/TPEL.2012.2185713](https://doi.org/10.1109/TPEL.2012.2185713) | Versão anterior do mesmo grupo; critério de reinício e oscilação em regime |
| `miyatake` **[C]** | Miyatake, Veerachary, Toriumi, Fujii, Ko. Maximum power point tracking of multiple photovoltaic arrays: a PSO approach. *IEEE Trans. Aerosp. Electron. Syst.* 47(1):367–380, 2011. [doi:10.1109/TAES.2011.5705681](https://doi.org/10.1109/TAES.2011.5705681) | Um dos primeiros PSO aplicados a MPPT com múltiplos picos |
| `liupso` **[C]** | Liu, Huang, Huang, Liang. A particle swarm optimization-based maximum power point tracking algorithm for PV systems operating under partially shaded conditions. *IEEE Trans. Energy Convers.* 27(4):1027–1035, 2012. [doi:10.1109/TEC.2012.2219533](https://doi.org/10.1109/TEC.2012.2219533) | PSO sob sombreamento parcial com validação experimental; bom ponto de comparação |

## Normas, perfis de teste e contexto

| Chave | Referência | Uso no trabalho |
|---|---|---|
| `en50530` **[P]** | CENELEC. *EN 50530: Overall efficiency of grid connected photovoltaic inverters*. Bruxelas, 2010. | Perfil de irradiância para eficiência dinâmica do MPPT |
| `pinho` **[P]** | Pinho, Galdino (org.). *Manual de Engenharia para Sistemas Fotovoltaicos*. Rio de Janeiro: CEPEL/CRESESB, 2014. | Contexto brasileiro e dados de irradiação |
| `anterior` **[P]** | Daga, Schneider Junior. *Energia Fotovoltaica com Conversor Buck-Boost*. Trabalho final de DAS5109, UFSC. | Trabalho do semestre anterior que este estende (`pdfs/anterior.pdf`) |

## Datasheets

Ficam em [`datasheets/`](datasheets/) e são versionados (documentos públicos do fabricante).

- **ZTROON ZTP-160M**: [`ZTP-160M_Datasheet_v.4.2.pdf`](datasheets/ZTP-160M_Datasheet_v.4.2.pdf), usado na Tarefa 3 (D8 do plano).
- **Kyocera KC200GT**: a obter; confirmar `Nsub` e `NOCT` antes de citar no relatório (Tarefa 2).
  Enquanto isso, os valores vêm da Tabela I de `villalva`.
