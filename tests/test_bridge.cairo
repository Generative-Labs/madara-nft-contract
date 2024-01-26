use core::debug::PrintTrait;
use snforge_std::{declare, ContractClassTrait, start_prank};
use web3mq_bridge_contract::bridge::IBridgeDispatcher;
use web3mq_bridge_contract::bridge::IBridgeDispatcherTrait;

use starknet::ContractAddress;
use starknet::contract_address::Felt252TryIntoContractAddress;

fn deploy_contract(name: felt252) -> ContractAddress {
    let contract = declare(name);
    contract.deploy(@array![0x024f4db2125B03D36C7D6ceab0e1213e30D92c4B1A71E2b10AeBFB24F2d4d0e4, 150264886235973633303855192769001132339554791641408004902857732345681964931, 0x0474d3ba382217b58f873706f514a6a2946b6b206f9c0bd9d4bb81c8dd673deb]).unwrap()
}

#[test]
fn test(){
    let contract_address = deploy_contract('Web3mqBridge');
    contract_address.print();
    let bridge_dispatcher = IBridgeDispatcher { contract_address };
    // let addr_1 = 0x024f4db2125B03D36C7D6ceab0e1213e30D92c4B1A71E2b10AeBFB24F2d4d0e4.try_into().unwrap();
    // start_prank(contract_address, addr_1);
    // 0x576bf94d0ab059e3bebbaf9ba17a2aaaa7eb9b24f0b2966b5670c200d68f6d0.try_into().unwrap()
    // market_dispatcher.append_support_token(0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap());

    // market_dispatcher.list_order(0x1345065f3ae0d45790473016fe4a2e8c,0x576bf94d0ab059e3bebbaf9ba17a2aaaa7eb9b24f0b2966b5670c200d68f6d0.try_into().unwrap(), 2299999999999999700, 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap(), 2717318335776711177724867463959070589973404041218771830612769497948035949981, 2441489929609207907306630385097115243919073745188760701537670792651754769586);

    // market_dispatcher.buy_order(0x1345065f3ae0d45790473016fe4a2e8c, 2299999999999999700, 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap(), false, array![0x1], 0x0, 0x0);
}