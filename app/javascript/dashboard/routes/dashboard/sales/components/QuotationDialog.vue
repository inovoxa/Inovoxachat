<script setup>
import { computed, reactive, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CompaniesAPI from 'dashboard/api/companies';
import AgentAPI from 'dashboard/api/agents';
import EquipmentsAPI from 'dashboard/api/equipments';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save', 'enviar', 'confirmar', 'cancelar']);

const dialogRef = ref(null);
const empresas = ref([]);
const agentes = ref([]);
const contatos = ref([]);
const equipamentos = ref([]);

const STATUS = [
  { key: 'cotacao', label: 'Cotação' },
  { key: 'enviada', label: 'Cotação enviada' },
  { key: 'pedido', label: 'Pedido de venda' },
];
const PLANOS = [
  { key: 'nenhum', label: 'Sem recorrência' },
  { key: 'mensalmente', label: 'Mensalmente' },
  { key: 'trimestralmente', label: 'Trimestralmente' },
  { key: 'semestralmente', label: 'Semestralmente' },
  { key: 'anualmente', label: 'Anualmente' },
];

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  number: '',
  status: 'cotacao',
  company_id: '',
  contact_id: '',
  agent_id: '',
  expiration_date: '',
  recurring_plan: 'nenhum',
  recurring_until: '',
  payment_terms: '',
  delivery_date: '',
  notes: '',
  lines: [],
});
const form = reactive(EMPTY());
const isEdit = computed(() => !!form.id);
const isInvalid = computed(() => !form.company_id && !form.contact_id);

function fmtValor(v) {
  return Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function lineTotal(l) {
  if (l.is_section) return 0;
  let base = Number(l.qty || 0) * Number(l.unit_price || 0);
  base -= base * (Number(l.discount_percent || 0) / 100);
  base += base * (Number(l.tax_percent || 0) / 100);
  return base;
}
const total = computed(() =>
  form.lines.filter(l => !l.is_section).reduce((s, l) => s + lineTotal(l), 0)
);

const reset = () => Object.assign(form, EMPTY());

function addProduto() {
  form.lines.push({
    id: null, equipment_id: '', is_section: false, name: '',
    qty: 1, unit_price: 0, tax_percent: 0, discount_percent: 0,
    position: form.lines.length,
  });
}
function addSecao() {
  form.lines.push({
    id: null, equipment_id: '', is_section: true, name: 'Nova seção',
    qty: 0, unit_price: 0, tax_percent: 0, discount_percent: 0,
    position: form.lines.length,
  });
}
function removerLinha(i) {
  form.lines.splice(i, 1);
}
function aoEscolherEquipamento(l) {
  const eq = equipamentos.value.find(e => String(e.id) === String(l.equipment_id));
  if (eq && !l.name) l.name = eq.name;
}

async function carregarContatos(companyId) {
  contatos.value = [];
  if (!companyId) return;
  try {
    const { data } = await CompaniesAPI.listContacts(companyId);
    contatos.value = data.payload || [];
  } catch (e) {
    contatos.value = [];
  }
}
watch(() => form.company_id, id => carregarContatos(id));

async function carregarOpcoes() {
  try {
    const { data } = await CompaniesAPI.get({});
    empresas.value = data.payload || [];
  } catch (e) {
    empresas.value = [];
  }
  try {
    const { data } = await AgentAPI.get();
    agentes.value = data || [];
  } catch (e) {
    agentes.value = [];
  }
  try {
    const { data } = await EquipmentsAPI.get({});
    equipamentos.value = data.payload || [];
  } catch (e) {
    equipamentos.value = [];
  }
}

const open = async (q = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: q.id || null,
    number: q.number || '',
    status: q.status || 'cotacao',
    company_id: q.company_id || '',
    contact_id: q.contact_id || '',
    agent_id: q.agent_id || '',
    expiration_date: q.expiration_date || '',
    recurring_plan: q.recurring_plan || 'nenhum',
    recurring_until: q.recurring_until || '',
    payment_terms: q.payment_terms || '',
    delivery_date: q.delivery_date || '',
    notes: q.notes || '',
    lines: (q.lines || []).map(l => ({ ...l })),
  });
  if (form.company_id) await carregarContatos(form.company_id);
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    company_id: form.company_id || null,
    contact_id: form.contact_id || null,
    agent_id: form.agent_id || null,
    expiration_date: form.expiration_date || null,
    recurring_plan: form.recurring_plan,
    recurring_until: form.recurring_until || null,
    payment_terms: form.payment_terms.trim() || null,
    delivery_date: form.delivery_date || null,
    notes: form.notes.trim() || null,
    quotation_lines_attributes: form.lines.map((l, i) => ({
      id: l.id || undefined,
      equipment_id: l.equipment_id || null,
      is_section: l.is_section,
      name: l.name,
      qty: Number(l.qty) || 0,
      unit_price: Number(l.unit_price) || 0,
      tax_percent: Number(l.tax_percent) || 0,
      discount_percent: Number(l.discount_percent) || 0,
      position: i,
      _destroy: l._destroy || undefined,
    })),
  });
};

const onSuccess = () => {
  reset();
  dialogRef.value?.close();
};

defineExpose({ open, onSuccess, dialogRef });
</script>

<template>
  <Dialog ref="dialogRef" width="4xl" :show-confirm-button="false" @confirm="confirm" @close="reset">
    <div class="flex flex-col gap-4">
      <!-- Pipeline de status (Odoo-like) -->
      <div class="flex items-center justify-between gap-2 flex-wrap">
        <span class="text-lg font-bold text-n-slate-12">
          {{ form.number || 'Nova cotação' }}
        </span>
        <div v-if="isEdit" class="flex items-center gap-1">
          <span
            v-for="(s, i) in STATUS"
            :key="s.key"
            class="text-xs px-3 py-1 font-medium"
            :class="[
              form.status === s.key
                ? 'bg-woot-500 text-white'
                : 'bg-n-alpha-black2 text-n-slate-11',
              i === 0 ? 'rounded-l-lg' : '',
              i === STATUS.length - 1 ? 'rounded-r-lg' : '',
            ]"
          >
            {{ s.label }}
          </span>
          <span
            v-if="form.status === 'cancelada'"
            class="text-xs px-3 py-1 rounded-lg bg-red-500/15 text-red-600 font-medium ml-1"
          >
            Cancelada
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Cliente (empresa)</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Contato</span>
          <select v-model="form.contact_id" :disabled="isLoading || !contatos.length" :class="inputClass">
            <option value="">—</option>
            <option v-for="c in contatos" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Vendedor</span>
          <select v-model="form.agent_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="a in agentes" :key="a.id" :value="a.id">{{ a.available_name || a.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Expiração</span>
          <input v-model="form.expiration_date" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Plano recorrente</span>
          <select v-model="form.recurring_plan" :disabled="isLoading" :class="inputClass">
            <option v-for="p in PLANOS" :key="p.key" :value="p.key">{{ p.label }}</option>
          </select>
        </label>
        <label v-if="form.recurring_plan !== 'nenhum'" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Recorrente até</span>
          <input v-model="form.recurring_until" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Condições de pagamento</span>
          <Input v-model="form.payment_terms" placeholder="ex.: Imediato / 30 dias" :disabled="isLoading" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Data de entrega</span>
          <input v-model="form.delivery_date" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
      </div>

      <!-- Linhas do pedido -->
      <div class="rounded-lg border border-n-weak overflow-hidden">
        <div class="grid grid-cols-[1fr_70px_90px_70px_70px_100px_32px] gap-2 px-3 py-2 bg-n-alpha-black2 text-xs text-n-slate-11 font-medium">
          <span>Produto</span>
          <span class="text-right">Qtd</span>
          <span class="text-right">Preço un.</span>
          <span class="text-right">Imp. %</span>
          <span class="text-right">Desc. %</span>
          <span class="text-right">Valor</span>
          <span></span>
        </div>

        <div
          v-for="(l, i) in form.lines"
          :key="i"
          class="grid grid-cols-[1fr_70px_90px_70px_70px_100px_32px] gap-2 px-3 py-1.5 items-center border-t border-n-weak"
          :class="l.is_section ? 'bg-n-alpha-black1' : ''"
        >
          <template v-if="l.is_section">
            <input v-model="l.name" placeholder="Nome da seção" class="col-span-6 h-7 bg-transparent text-sm font-semibold text-n-slate-12 outline-none" />
          </template>
          <template v-else>
            <div class="flex flex-col gap-0.5">
              <select v-model="l.equipment_id" class="h-7 rounded border border-n-weak bg-n-alpha-black2 px-1 text-xs text-n-slate-11" @change="aoEscolherEquipamento(l)">
                <option value="">— equipamento (opcional) —</option>
                <option v-for="e in equipamentos" :key="e.id" :value="e.id">{{ e.name }}</option>
              </select>
              <input v-model="l.name" placeholder="Descrição do produto" class="h-7 bg-transparent text-sm text-n-slate-12 outline-none" />
            </div>
            <input v-model="l.qty" type="number" step="0.01" min="0" class="h-7 rounded border border-n-weak bg-n-alpha-black2 px-1 text-sm text-right text-n-slate-12" />
            <input v-model="l.unit_price" type="number" step="0.01" min="0" class="h-7 rounded border border-n-weak bg-n-alpha-black2 px-1 text-sm text-right text-n-slate-12" />
            <input v-model="l.tax_percent" type="number" step="0.01" min="0" class="h-7 rounded border border-n-weak bg-n-alpha-black2 px-1 text-sm text-right text-n-slate-12" />
            <input v-model="l.discount_percent" type="number" step="0.01" min="0" class="h-7 rounded border border-n-weak bg-n-alpha-black2 px-1 text-sm text-right text-n-slate-12" />
            <span class="text-sm text-right text-n-slate-12">{{ fmtValor(lineTotal(l)) }}</span>
          </template>
          <button type="button" class="text-n-slate-11 hover:text-red-500 justify-self-end" @click="removerLinha(i)">🗑</button>
        </div>

        <div class="flex items-center gap-4 px-3 py-2 border-t border-n-weak">
          <button type="button" class="text-xs text-woot-500 hover:underline" @click="addProduto">+ Adicionar produto</button>
          <button type="button" class="text-xs text-woot-500 hover:underline" @click="addSecao">+ Adicionar seção</button>
        </div>
      </div>

      <div class="flex justify-end items-baseline gap-3">
        <span class="text-sm text-n-slate-11">Total</span>
        <span class="text-2xl font-bold text-woot-600">{{ fmtValor(total) }}</span>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Anotações</span>
        <textarea
          v-model="form.notes"
          rows="2"
          :disabled="isLoading"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
      </label>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <div class="flex items-center gap-2">
          <Button label="Fechar" variant="link" @click="dialogRef?.close()" />
          <template v-if="isEdit && form.status !== 'pedido' && form.status !== 'cancelada'">
            <Button label="Enviar" color="slate" :disabled="isLoading" @click="emit('enviar', { id: form.id })" />
            <Button label="Confirmar" color="teal" :disabled="isLoading" @click="emit('confirmar', { id: form.id })" />
            <Button label="Cancelar cotação" color="ruby" variant="ghost" :disabled="isLoading" @click="emit('cancelar', { id: form.id })" />
          </template>
        </div>
        <Button
          label="Salvar"
          color="blue"
          type="submit"
          :disabled="isInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
