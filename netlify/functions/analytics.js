exports.handler = async function (event, context) {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  const fs = require('fs');
  const path = require('path');
  const filePath = path.join(__dirname, '..', '..', 'analytics.json');

  let data = {};
  try {
    data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    data = {};
  }

  if (event.httpMethod === 'GET') {
    return {
      statusCode: 200,
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    };
  }

  if (event.httpMethod === 'POST') {
    const body = event.body ? JSON.parse(event.body) : {};
    const action = body.action || 'open';
    const photo = body.photo || 'all';

    if (!data[photo]) {
      data[photo] = { opens: 0, saves: 0 };
    }

    if (action === 'open') {
      data[photo].opens += 1;
    } else if (action === 'save') {
      data[photo].saves += 1;
    }

    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));

    return {
      statusCode: 200,
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify(data[photo])
    };
  }

  return { statusCode: 405, headers, body: 'Method not allowed' };
};
