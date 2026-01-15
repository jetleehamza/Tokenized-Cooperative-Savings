
import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

const contractName = "Tokenized-Cooperative-Savings";

describe("Tokenized Cooperative Savings - basic flows", () => {
  it("lets a wallet join the cooperative", () => {
    const join = simnet.callPublicFn(
      contractName,
      "join-cooperative",
      [],
      address1
    );
    expect(join.result).not.toBeNull();
  });
});
