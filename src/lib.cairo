use starknet::ContractAddress;

// Define the contract interface
#[starknet::interface]
pub trait IPointsRegistry<TContractState> {
    /// Adds points to a specific user's balance.
    fn add_points(ref self: TContractState, user: ContractAddress, amount: u32);

    /// Redeems points from the caller's balance.
    /// Asserts that the caller has sufficient points.
    fn redeem_points(ref self: TContractState, amount: u32);

    /// Gets the points balance for a specific user.
    fn get_balance(self: @TContractState, user: ContractAddress) -> u32;

    /// Transfers points from the caller's balance to another user.
    /// Asserts that the caller has sufficient points.
    fn transfer_points(ref self: TContractState, to: ContractAddress, amount: u32);
}

// Define the contract module
#[starknet::contract]
pub mod PointsRegistry {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;


    // Define storage variables
    #[storage]
    pub struct Storage {
        // Mapping to store user points: ContractAddress -> Points Balance
        points: Map<ContractAddress, u32>,
    }

    // Define events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PointsAdded: PointsAdded,
        PointsRedeemed: PointsRedeemed,
        PointsTransferred: PointsTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PointsAdded {
        #[key] user: ContractAddress,
        amount: u32,
        new_balance: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PointsRedeemed {
        #[key] user: ContractAddress,
        amount: u32,
        new_balance: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PointsTransferred {
        #[key] from_user: ContractAddress,
        #[key] to_user: ContractAddress,
        amount: u32,
        from_balance: u32,
        to_balance: u32,
    }

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl PointsRegistryImpl of super::IPointsRegistry<ContractState> {
        /// Adds points to a specific user's balance.
        /// Emits a PointsAdded event.
        fn add_points(ref self: ContractState, user: ContractAddress, amount: u32) {
            // Get the current balance for the user. Map reads return Zeroable::zero() if key not found.
            let current_balance = self.points.entry(user).read();
            let new_balance = current_balance + amount;

            // Write the new balance to storage
            self.points.entry(user).write(new_balance);

            // Emit the PointsAdded event
            self.emit(Event::PointsAdded(PointsAdded { user, amount, new_balance }));
        }

        /// Redeems points from the caller's balance.
        /// Checks if the caller has enough points using assert.
        /// Emits a PointsRedeemed event.
        fn redeem_points(ref self: ContractState, amount: u32) {
            let caller = get_caller_address();
            let current_balance: u32 = self.points.entry(caller).read();

            // Assert that the caller has enough points
            assert(current_balance >= amount, 'INSUFFICIENT_POINTS');

            let new_balance = current_balance - amount;

            // Write the new balance to storage
            self.points.entry(caller).write(new_balance);

            // Emit the PointsRedeemed event
            self.emit(Event::PointsRedeemed(PointsRedeemed { user: caller, amount, new_balance }));
        }

        /// Gets the points balance for a specific user.
        /// This is a view function and does not modify state.
        fn get_balance(self: @ContractState, user: ContractAddress) -> u32 {
            // Read the balance for the user. Returns 0 if the user has no entry yet.
            self.points.entry(user).read()
        }

        /// Transfers points from the caller's balance to another user.
        /// Asserts that the caller has sufficient points and is not transferring to self.
        /// Emits a PointsTransferred event.
        fn transfer_points(ref self: ContractState, to: ContractAddress, amount: u32) {
            let from = get_caller_address();

            // Prevent transferring to self
            assert(from != to, 'CANNOT_TRANSFER_TO_SELF');

            // Get balances for both users
            let from_balance = self.points.entry(from).read();
            let to_balance = self.points.entry(to).read();

            // Assert that the sender has enough points
            assert(from_balance >= amount, 'INSUFFICIENT_POINTS');

            // Calculate new balances
            let new_from_balance = from_balance - amount;
            let new_to_balance = to_balance + amount;

            // Update balances in storage
            self.points.entry(from).write(new_from_balance);
            self.points.entry(to).write(new_to_balance);

            // Emit the PointsTransferred event
            self.emit(Event::PointsTransferred(PointsTransferred {
                from_user: from,
                to_user: to,
                amount,
                from_balance: new_from_balance,
                to_balance: new_to_balance,
            }));
        }
    }
}