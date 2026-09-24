import buildConsumer from "channels/consumer"

export function subscribeToSales(received) {
  const consumer = buildConsumer()
  const subscription = consumer.subscriptions.create("SaleNotificationsChannel", { received })

  return () => {
    subscription.unsubscribe()
    consumer.disconnect()
  }
}
