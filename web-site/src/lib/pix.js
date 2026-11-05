// Pix para apoiar o projeto. Igual no app (lib/services/pix.dart).
// Preencha a chave, o nome e a cidade de quem recebe; vazio = o cartão de
// apoio não aparece.

export const PIX = {
  key: 'b2f17626-44c0-421d-9a60-71a33b272741',
  name: 'PocketDex', // até 25 letras, sem acento
  city: 'Brasil', // até 15 letras, sem acento
}

export const pixEnabled = () => Boolean(PIX.key && PIX.name && PIX.city)

const field = (id, value) => `${id}${String(value.length).padStart(2, '0')}${value}`

const plain = (text, max) =>
  text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^A-Za-z0-9 ]/g, '')
    .slice(0, max)

/** CRC16-CCITT (0x1021, começa em 0xFFFF), como pede o padrão do Pix. */
export function crc16(text) {
  let crc = 0xffff
  for (const byte of new TextEncoder().encode(text)) {
    crc ^= byte << 8
    for (let i = 0; i < 8; i++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff
  }
  return crc.toString(16).toUpperCase().padStart(4, '0')
}

/** Código "Pix copia e cola" (BR Code) sem valor fixo: a pessoa escolhe quanto doar. */
export function pixCode({ key, name, city } = PIX) {
  const payload =
    field('00', '01') +
    field('26', field('00', 'br.gov.bcb.pix') + field('01', key)) +
    field('52', '0000') +
    field('53', '986') +
    field('58', 'BR') +
    field('59', plain(name, 25)) +
    field('60', plain(city, 15)) +
    field('62', field('05', '***')) +
    '6304'
  return payload + crc16(payload)
}
