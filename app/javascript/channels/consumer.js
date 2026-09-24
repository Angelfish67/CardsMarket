import { createConsumer } from "@rails/actioncable"

export default function buildConsumer() {
  return createConsumer()
}
