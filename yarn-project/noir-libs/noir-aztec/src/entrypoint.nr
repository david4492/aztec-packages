use crate::abi;
use crate::types::vec::BoundedVec;
use crate::context::Context;
use crate::private_call_stack_item::PrivateCallStackItem;
use crate::public_call_stack_item::PublicCallStackItem;    

global ACCOUNT_MAX_PRIVATE_CALLS: comptime Field = 1;
global ACCOUNT_MAX_PUBLIC_CALLS: comptime Field = 1;
global ACCOUNT_MAX_CALLS: comptime Field = 2;
// 1 (ARGS_HASH) + 1 (FUNCTION_SELECTOR) + 1 (TARGET_ADDRESS)
global FUNCTION_CALL_SIZE: comptime Field = 3;

struct FunctionCall {
  args_hash: Field,
  function_selector: Field,
  target_address: Field,
}

impl FunctionCall {
  fn serialize(self) -> [Field; FUNCTION_CALL_SIZE] {
    [self.args_hash, self.function_selector, self.target_address]
  }
}

// FUNCTION_CALL_SIZE * (ACCOUNT_MAX_PUBLIC_CALLS + ACCOUNT_MAX_PRIVATE_CALLS) + 1
global ENTRYPOINT_PAYLOAD_SIZE: comptime Field = 7;
global ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES: comptime Field = 224;

struct EntrypointPayload {
  // Noir doesnt support nested arrays or structs yet so we flatten everything
  flattened_args_hashes: [Field; ACCOUNT_MAX_CALLS],
  flattened_selectors: [Field; ACCOUNT_MAX_CALLS],
  flattened_targets: [Field; ACCOUNT_MAX_CALLS],
  nonce: Field,
}

impl EntrypointPayload {
  // TODO hash_index
  fn hash(self) -> Field {
    dep::std::hash::pedersen(self.serialize())[0]
  }

  // Serializes the entrypoint struct
  fn serialize(self) -> [Field; ENTRYPOINT_PAYLOAD_SIZE] {
    let mut fields: BoundedVec<Field, ENTRYPOINT_PAYLOAD_SIZE> = BoundedVec::new(0); 
    fields = fields.push_array(self.flattened_args_hashes);
    fields = fields.push_array(self.flattened_selectors);
    fields = fields.push_array(self.flattened_targets);
    fields = fields.push(self.nonce);
    fields.storage
  }

  // Serializes the payload as an array of bytes. Useful for hashing with sha256.
  fn to_be_bytes(self) -> [u8; ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES] {
    let mut bytes: [u8; ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES] = [0; ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES];

    let args_len = self.flattened_args_hashes.len();
    let selectors_len = self.flattened_selectors.len();
    let targets_len = self.flattened_targets.len();

    for i in 0..args_len {
      let item_bytes = self.flattened_args_hashes[i].to_be_bytes(32);
      for j in 0..32 { 
        bytes[i * 32 + j] = item_bytes[j];
      }
    }

    for i in 0..selectors_len {
      let item_bytes = self.flattened_selectors[i].to_be_bytes(32);
      for j in 0..32 { 
        bytes[args_len * 32 + i * 32 + j] = item_bytes[j];
      }
    }

    for i in 0..targets_len {
      let item_bytes = self.flattened_targets[i].to_be_bytes(32);
      for j in 0..32 { 
        bytes[(args_len + selectors_len) * 32 + i * 32 + j] = item_bytes[j];
      }
    }
    
    let item_bytes = self.nonce.to_be_bytes(32);
    for j in 0..32 { 
      bytes[(args_len + selectors_len + targets_len) * 32 + j] = item_bytes[j];
    }

    bytes
  }

  // Executes all private and public calls 
  fn execute_calls(self, mut context: Context) -> Context {
    for i in 0..ACCOUNT_MAX_PRIVATE_CALLS {
        let target_address = self.flattened_targets[i];
        if target_address != 0 {
            let function_selector = self.flattened_selectors[i];
            let args_hash = self.flattened_args_hashes[i];
            let (_callStackItem, updated_context) = PrivateCallStackItem::call_with_packed_args(target_address, function_selector, args_hash, context);
            context = updated_context;
        }
    }
    for i in ACCOUNT_MAX_PRIVATE_CALLS..ACCOUNT_MAX_CALLS {
        let target_address = self.flattened_targets[i];
        if target_address != 0 {
            let function_selector = self.flattened_selectors[i];
            let args_hash = self.flattened_args_hashes[i];
            let (_callStackItem, updated_context) = PublicCallStackItem::call_with_packed_args(target_address, function_selector, args_hash, context);
            context = updated_context;
        }
    }
    context
  }

  // TODO: This function returns all zeroes. Figure out why!
  fn to_be_bytes_fail(self) -> [u8; ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES] {
    let mut bytes: BoundedVec<u8, ENTRYPOINT_PAYLOAD_SIZE_IN_BYTES> = BoundedVec::new(0);

    // Noir crashes if we try to push_bytes the whole item_bytes into the vec
    // See https://github.com/noir-lang/noir/issues/1023
    for item in self.flattened_args_hashes {
      let item_bytes = item.to_be_bytes(32);
      for i in 0..32 { 
        bytes.push(item_bytes[i]); 
      }
    }
    for item in self.flattened_selectors {
      let item_bytes = item.to_be_bytes(32);
      for i in 0..32 { 
        bytes.push(item_bytes[i]); 
      }
    }
    for item in self.flattened_targets {
      let item_bytes = item.to_be_bytes(32);
      for i in 0..32 { 
        bytes.push(item_bytes[i]); 
      }
    }
    
    let nonce_bytes = self.nonce.to_be_bytes(32);
    for i in 0..32 { 
      bytes.push(nonce_bytes[i]); 
    }
    bytes.storage
  }
}