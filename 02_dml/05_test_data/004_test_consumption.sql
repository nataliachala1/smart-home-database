INSERT INTO consumption.consumption (
  id_consumption, id_device, fecha_hora, consumo_w,
  created_at, updated_at
)

VALUES
  -- Consumo de la lámpara sala
  (
    'e1000000-0000-0000-0000-000000000001',
    '2024-06-01 08:00:00', 10.00,
    NOW(), NOW()
  ),
  (
    'e1000000-0000-0000-0000-000000000001',
    '2024-06-01 12:00:00', 15.00,
    NOW(), NOW()
  ),
  (
    'e1000000-0000-0000-0000-000000000001',
    '2024-06-01 18:00:00', 20.00,
    NOW(), NOW()
  ),
  -- Consumo del televisor sala
  (
    'e1000000-0000-0000-0000-000000000002',
    '2024-06-01 08:00:00', 100.00,
    NOW(), NOW()
  ),
  (
    'e1000000-0000-0000-0000-000000000002',
    '2024-06-01 12:00:00', 120.00,
    NOW(), NOW()
  ),
  (

    'e1000000-0000-0000-0000-000000000002',
    '2024-06-01 18:00:00', 150.00,
  ); 

INSERT INTO consumption.consumption_metric (
  id_consumption_metrics, id_device, fecha_hora,
  consumo_w, created_at, updated_at
)