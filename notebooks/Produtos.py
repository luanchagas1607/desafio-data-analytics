import pandas as pd

arquivo_entrada = r"C:\Users\pcarr\Downloads\desafio-data-analytics-main\desafio-data-analytics-main\Base-Dados-Desafio-500k.xlsx"

df = pd.read_excel(arquivo_entrada, sheet_name="PRODUTOS")
df = df.fillna("NÃO INFORMADO")

dataset = df
