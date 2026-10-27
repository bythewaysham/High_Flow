import { z } from 'zod';

export const orderSchema = z
  .object({
    customerRef: z.string().trim().min(1).max(100).optional(),
    priority: z.enum(['normal', 'rush']).default('normal'),
    items: z
      .array(
        z
          .object({
            sku: z.string().trim().min(1).max(80),
            quantity: z.number().int().min(1).max(1000),
          })
          .strict(),
      )
      .min(1)
      .max(100),
  })
  .strict()
  .refine(
    (order) => new Set(order.items.map((item) => item.sku)).size === order.items.length,
    { message: 'Each product SKU can appear only once in an order.', path: ['items'] },
  );

export const scanSchema = z
  .object({
    eventId: z.string().uuid(),
    robotId: z.string().trim().min(1).max(40),
    scanCode: z.string().trim().min(1).max(100),
    scanType: z.enum(['pick', 'deliver']),
    metadata: z.record(z.string(), z.unknown()).default({}),
  })
  .strict();

export const telemetrySchema = z
  .object({
    x: z.number().int().min(0).max(1000),
    y: z.number().int().min(0).max(1000),
    battery: z.number().int().min(0).max(100),
    status: z
      .enum(['idle', 'moving', 'picking', 'delivering', 'charging', 'unavailable'])
      .optional(),
  })
  .strict();

export const productSchema = z
  .object({
    sku: z.string().trim().min(1).max(80),
    name: z.string().trim().min(1).max(160),
    category: z.string().trim().min(1).max(80).default('General'),
    scanCode: z.string().trim().min(1).max(100),
    onHand: z.number().int().min(0).max(1_000_000),
    bin: z
      .object({
        x: z.number().int().min(0).max(1000),
        y: z.number().int().min(0).max(1000),
      })
      .strict(),
  })
  .strict();
