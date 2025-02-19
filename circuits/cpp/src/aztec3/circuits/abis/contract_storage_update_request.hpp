#pragma once
#include "aztec3/utils/msgpack_derived_output.hpp"
#include "aztec3/utils/types/circuit_types.hpp"
#include "aztec3/utils/types/convert.hpp"
#include "aztec3/utils/types/native_types.hpp"

#include <barretenberg/barretenberg.hpp>

namespace aztec3::circuits::abis {

using aztec3::utils::types::CircuitTypes;
using aztec3::utils::types::NativeTypes;
using plonk::stdlib::witness_t;

template <typename NCT> struct ContractStorageUpdateRequest {
    using fr = typename NCT::fr;
    using boolean = typename NCT::boolean;

    fr storage_slot = 0;
    fr old_value = 0;
    fr new_value = 0;

    // for serialization, update with new fields
    MSGPACK_FIELDS(storage_slot, old_value, new_value);
    bool operator==(ContractStorageUpdateRequest<NCT> const&) const = default;
    template <typename Builder>
    ContractStorageUpdateRequest<CircuitTypes<Builder>> to_circuit_type(Builder& builder) const
    {
        static_assert((std::is_same<NativeTypes, NCT>::value));

        // Capture the circuit builder:
        auto to_ct = [&](auto& e) { return aztec3::utils::types::to_ct(builder, e); };

        ContractStorageUpdateRequest<CircuitTypes<Builder>> update_request = {
            to_ct(storage_slot),
            to_ct(old_value),
            to_ct(new_value),
        };

        return update_request;
    };

    template <typename Builder> ContractStorageUpdateRequest<NativeTypes> to_native_type() const
    {
        static_assert((std::is_same<CircuitTypes<Builder>, NCT>::value));

        auto to_nt = [&](auto& e) { return aztec3::utils::types::to_nt<Builder>(e); };

        ContractStorageUpdateRequest<NativeTypes> update_request = {
            to_nt(storage_slot),
            to_nt(old_value),
            to_nt(new_value),
        };

        return update_request;
    };

    fr hash() const
    {
        std::vector<fr> const inputs = {
            storage_slot,
            old_value,
            new_value,
        };

        return NCT::compress(inputs, GeneratorIndex::PUBLIC_DATA_UPDATE_REQUEST);
    }

    void set_public()
    {
        static_assert(!(std::is_same<NativeTypes, NCT>::value));

        storage_slot.set_public();
        old_value.set_public();
        new_value.set_public();
    }

    boolean is_empty() const { return storage_slot == 0; }
};

template <typename NCT>
std::ostream& operator<<(std::ostream& os, ContractStorageUpdateRequest<NCT> const& update_request)
{
    utils::msgpack_derived_output(os, update_request);
    return os;
}

}  // namespace aztec3::circuits::abis
