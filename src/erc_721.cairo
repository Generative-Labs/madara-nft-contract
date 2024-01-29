use core::zeroable::Zeroable;
use starknet::ContractAddress;

#[starknet::interface]
trait IERC721<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
}

#[starknet::interface]
trait IMadaraNFT<TContractState> {
    fn mint_with_url(ref self: TContractState, token_id: u256, token_uri: felt252);
}

#[starknet::contract]
mod MadaraNFT {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use core::traits::Into;

    #[storage]
    struct Storage {
        ERC721_name: felt252,
        ERC721_symbol: felt252,
        ERC721_owners: LegacyMap<u256, ContractAddress>,
        ERC721_balances: LegacyMap<ContractAddress, u256>,
        ERC721_token_approvals: LegacyMap<u256, ContractAddress>,
        ERC721_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC721_token_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables or disables (`approved`) `operator` to manage
    /// all of its assets.
    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC721: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC721: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC721: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC721: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC721: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC721: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC721: token already minted';
        const WRONG_SENDER: felt252 = 'ERC721: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC721: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    fn constructor (ref self: ContractState){
        self.ERC721_name.write('MadaraNFT');
        self.ERC721_symbol.write('MNFT');
    }

    //
    // External
    //
    #[external(v0)] 
    impl MadaraNFTImpl of super::IMadaraNFT<ContractState>{
        fn mint_with_url(ref self: ContractState, token_id: u256, token_uri: felt252){
            self._mint(get_caller_address(), token_id);
            self.ERC721_token_uri.write(token_id, token_uri);
        }
    }

    #[external(v0)]
    impl ERC721 of super::IERC721<ContractState>{
        fn name(self: @ContractState) -> felt252 {
            self.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ContractState) -> felt252 {
            self.ERC721_symbol.read()
        }

        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set for the `token_id`, the return value will be `0`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.read(token_id)
        }

        /// Returns the number of NFTs owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.ERC721_balances.read(account)
        }

        /// Returns the owner address of `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        /// Transfers ownership of `token_id` from `from` to `to`.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `to` is not the zero address.
        /// - `from` is not the zero address.
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._transfer(from, to, token_id);
        }

        /// Change or reaffirm the approved address for an NFT.
        ///
        /// Requirements:
        ///
        /// - The caller is either an approved operator or the `token_id` owner.
        /// - `to` cannot be the token owner.
        /// - `token_id` exists.
        ///
        /// Emits an `Approval` event.
        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || self._is_approved_for_all(owner, caller), Errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller's assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `Approval` event.
        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        /// Returns the address approved for `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }
    }

     #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Initializes the contract by setting the token name and symbol.
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ContractState, name: felt252, symbol: felt252) {
            self.ERC721_name.write(name);
            self.ERC721_symbol.write(symbol);
        }

        /// Returns the owner address of `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn _owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.ERC721_owners.read(token_id);
            match owner.into() == 0{
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        /// Returns whether `token_id` exists.
        fn _exists(self: @ContractState, token_id: u256) -> bool {
            self.ERC721_owners.read(token_id).into() != 0
        }

        /// Returns whether `spender` is allowed to manage `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let approved: bool = self._is_approved_for_all(owner, spender);
            owner == spender || approved || spender == self._get_approved(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        fn _is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }

        fn _get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        /// Changes or reaffirms the approved address for an NFT.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        /// - `to` is not the current token owner.
        ///
        /// Emits an `Approval` event.
        fn _approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, Errors::APPROVAL_TO_OWNER);

            self.ERC721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        /// Enables or disables approval for `operator` to manage
        /// all of the `owner` assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `Approval` event.
        fn _set_approval_for_all(
            ref self: ContractState,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, Errors::SELF_APPROVAL);
            self.ERC721_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        /// Mints `token_id` and transfers it to `to`.
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - `token_id` does not exist.
        ///
        /// Emits a `Transfer` event.
        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(to.into()!=0, Errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), Errors::ALREADY_MINTED);

            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        /// Transfers `token_id` from `from` to `to`.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - `from` is the token owner.
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(to.into()!=0, Errors::INVALID_RECEIVER);
            let owner = self._owner_of(token_id);
            assert(from == owner, Errors::WRONG_SENDER);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(from, self.ERC721_balances.read(from) - 1);
            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from, to, token_id });
        }

        /// Destroys `token_id`. The approval is cleared when the token is burned.
        ///
        /// This internal function does not check if the caller is authorized
        /// to operate on the token.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
        fn _burn(ref self: ContractState, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(owner, self.ERC721_balances.read(owner) - 1);
            self.ERC721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        /// Sets the `token_uri` of `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn _set_token_uri(
            ref self: ContractState, token_id: u256, token_uri: felt252
        ) {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.write(token_id, token_uri)
        }
    }
}