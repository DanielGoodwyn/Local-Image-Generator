from modules.expansion import LocalImageGeneratorExpansion

expansion = LocalImageGeneratorExpansion()

text = 'a handsome man'

for i in range(64):
    print(expansion(text, seed=i))
