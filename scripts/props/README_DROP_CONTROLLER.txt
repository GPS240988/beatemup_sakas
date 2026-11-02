O controlador GamesBoxDropController é adicionado como filho do DestructibleGamesBox.
Ele escuta o sinal prop_destroyed e instancia dois PackedScenes irmãos na pasta Destructibles.
As posições usam o global_position da caixa e deslocamentos simétricos no eixo X.
