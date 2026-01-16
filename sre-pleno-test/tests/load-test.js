/*
 * Load Test para Online Boutique usando k6
 * Autor: Pablo Shizato
 * Data: Janeiro 2026
 * 
 * Instalação do k6:
 *   brew install k6  (macOS)
 *   ou baixe de: https://k6.io/docs/getting-started/installation/
 * 
 * Execução:
 *   k6 run tests/load-test.js
 *   k6 run --vus 10 --duration 30s tests/load-test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Métricas customizadas
const errorRate = new Rate('errors');
const homepageLoadTime = new Trend('homepage_load_time');
const productPageLoadTime = new Trend('product_page_load_time');
const checkoutTime = new Trend('checkout_time');
const requestCounter = new Counter('total_requests');

// Configuração do teste
export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp-up para 10 usuários
    { duration: '1m', target: 50 },   // Aumenta para 50 usuários
    { duration: '2m', target: 50 },   // Mantém 50 usuários
    { duration: '30s', target: 100 }, // Spike para 100 usuários
    { duration: '1m', target: 100 },  // Mantém 100 usuários
    { duration: '30s', target: 0 },   // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'], // 95% < 1s, 99% < 2s
    'http_req_failed': ['rate<0.01'],                   // Taxa de erro < 1%
    'errors': ['rate<0.05'],                            // Taxa de erro custom < 5%
  },
};

// Base URL (ajustar conforme necessário)
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Produtos de exemplo (IDs da Online Boutique)
const PRODUCTS = [
  'OLJCESPC7Z', // Vintage Typewriter
  '66VCHSJNUP', // Vintage Camera Lens
  '1YMWWN1N4O', // Home Barista Kit
  'L9ECAV7KIM', // Terrarium
  '2ZYFJ3GM2N', // Film Camera
  '0PUK6V6EV0', // Vintage Record Player
  'LS4PSXUNUM', // Metal Camping Mug
  '9SIQT8TOJO', // City Bike
  '6E92ZMYYFZ', // Air Plant
];

// Função auxiliar para selecionar produto aleatório
function getRandomProduct() {
  return PRODUCTS[Math.floor(Math.random() * PRODUCTS.length)];
}

// Função auxiliar para gerar session ID
function generateSessionId() {
  return `session-${Date.now()}-${Math.random().toString(36).substring(7)}`;
}

export default function () {
  const sessionId = generateSessionId();
  const headers = {
    'Cookie': `shop_session-id=${sessionId}`,
  };

  // Cenário 1: Acessar homepage
  let response = http.get(BASE_URL, { headers });
  requestCounter.add(1);
  
  const homepageSuccess = check(response, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage has products': (r) => r.body.includes('product'),
    'homepage loads in < 1s': (r) => r.timings.duration < 1000,
  });
  
  errorRate.add(!homepageSuccess);
  homepageLoadTime.add(response.timings.duration);
  
  sleep(1);

  // Cenário 2: Visualizar produto
  const productId = getRandomProduct();
  response = http.get(`${BASE_URL}/product/${productId}`, { headers });
  requestCounter.add(1);
  
  const productSuccess = check(response, {
    'product page status is 200': (r) => r.status === 200,
    'product page has details': (r) => r.body.includes('Add to Cart'),
    'product page loads in < 1s': (r) => r.timings.duration < 1000,
  });
  
  errorRate.add(!productSuccess);
  productPageLoadTime.add(response.timings.duration);
  
  sleep(2);

  // Cenário 3: Adicionar ao carrinho
  response = http.post(
    `${BASE_URL}/cart`,
    JSON.stringify({
      product_id: productId,
      quantity: Math.floor(Math.random() * 3) + 1,
    }),
    {
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    }
  );
  requestCounter.add(1);
  
  const addToCartSuccess = check(response, {
    'add to cart successful': (r) => r.status === 200 || r.status === 302,
  });
  
  errorRate.add(!addToCartSuccess);
  
  sleep(1);

  // Cenário 4: Ver carrinho
  response = http.get(`${BASE_URL}/cart`, { headers });
  requestCounter.add(1);
  
  const cartSuccess = check(response, {
    'cart page status is 200': (r) => r.status === 200,
    'cart has items': (r) => r.body.includes('Cart') || r.body.includes('Empty'),
  });
  
  errorRate.add(!cartSuccess);
  
  sleep(2);

  // Cenário 5: Checkout (25% dos usuários)
  if (Math.random() < 0.25) {
    const startCheckout = Date.now();
    
    response = http.post(
      `${BASE_URL}/cart/checkout`,
      JSON.stringify({
        email: `user${sessionId}@example.com`,
        street_address: '123 Main St',
        zip_code: '12345',
        city: 'San Francisco',
        state: 'CA',
        country: 'US',
        credit_card_number: '4111-1111-1111-1111',
        credit_card_expiration_month: '12',
        credit_card_expiration_year: '2025',
        credit_card_cvv: '123',
      }),
      {
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      }
    );
    requestCounter.add(1);
    
    const checkoutSuccess = check(response, {
      'checkout successful': (r) => r.status === 200 || r.status === 302,
      'checkout completes in < 3s': (r) => r.timings.duration < 3000,
    });
    
    errorRate.add(!checkoutSuccess);
    checkoutTime.add(Date.now() - startCheckout);
    
    sleep(3);
  }

  // Cenário 6: Buscar produtos (10% dos usuários)
  if (Math.random() < 0.1) {
    const searchTerms = ['vintage', 'camera', 'plant', 'bike', 'mug'];
    const searchTerm = searchTerms[Math.floor(Math.random() * searchTerms.length)];
    
    response = http.get(`${BASE_URL}/?search=${searchTerm}`, { headers });
    requestCounter.add(1);
    
    check(response, {
      'search results status is 200': (r) => r.status === 200,
    });
    
    sleep(1);
  }

  // Pausa entre iterações (simula tempo de leitura)
  sleep(Math.random() * 3 + 1); // 1-4 segundos
}

// Função executada ao final do teste
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'results/load-test-summary.json': JSON.stringify(data),
  };
}

// Função para gerar resumo textual
function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;
  
  let summary = '\n';
  summary += `${indent}Test Summary\n`;
  summary += `${indent}============\n\n`;
  
  // Estatísticas gerais
  summary += `${indent}Duration: ${data.state.testRunDurationMs}ms\n`;
  summary += `${indent}VUs: ${data.metrics.vus.values.max}\n`;
  summary += `${indent}Iterations: ${data.metrics.iterations.values.count}\n\n`;
  
  // HTTP metrics
  summary += `${indent}HTTP Metrics:\n`;
  summary += `${indent}  Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}  Failed: ${data.metrics.http_req_failed.values.rate * 100}%\n`;
  summary += `${indent}  Duration (avg): ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `${indent}  Duration (p95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `${indent}  Duration (p99): ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n\n`;
  
  // Custom metrics
  if (data.metrics.errors) {
    summary += `${indent}Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%\n`;
  }
  
  return summary;
}

