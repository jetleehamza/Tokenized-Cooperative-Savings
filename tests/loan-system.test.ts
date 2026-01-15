import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const wallet1 = accounts.get("wallet_1")!;

const contractName = "Tokenized-Cooperative-Savings";

describe("Loan System - read-only check", () => {
  it("returns an initial loan count", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-loan-count",
      [],
      wallet1
    );

    expect(result).not.toBeNull();
  });
});
