supersim fork --chains op,base --interop.autorelay

---

Spoke Chain(OP):

agent: 0x31842da3bc6eB9fe0Ba9F2b332B7965d75309041
tokenMock:  0xb42Cfe81B72A2a3be27BA2f7D3D3eBD4Cc157661

---

Hub Chain(Base):

broker: 0x51C77C751129810EA6CBF8fC11CfA8060F4d5312

PegTokenFactory: 0x9954EF92D8ac2b3c5E86B56AaAa291F09A592320

ampli: 0x00D6aFb06576DEA356cBa9F44Ba71aB4eb780Ac0
(forge script script/Deploy.s.sol:DeployHook --rpc-url http://127.0.0.1:9546/ --private-key $BROKER_PRIVATE_KEY --broadcast)

forge script script/RouterDeployScript.sol:RouterDeployScript --broadcast
v4MiniRouter:  0x94Ee008827eDaFdCE093aca968a958D20e7C5cE6
v4RouterHelper:  0x65648b6F8bFfA61E8472050E65D940a984a61391
actionsRouter:  0x02F53f0e4924DfB01FFaD12F5536110B516266Ea
hubExecutor:  0x934F58ADbda47765F81727894803D497fb7d68F3

tokenMock:  0xb42Cfe81B72A2a3be27BA2f7D3D3eBD4Cc157661
pegToken:  0x9E357a7ee75914452f06DdFb9622f924276024a3

irm:  0x05180215c45Dda1718AFfd8739058DE533455Ec8
oracle:  0x6C3CcB6B61E078BCc2cB03eC5F6dd6E706366232

