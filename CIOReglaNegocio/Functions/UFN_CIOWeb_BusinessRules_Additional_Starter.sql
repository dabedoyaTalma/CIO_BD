/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_Starter]    Script Date: 09/05/2023 15:02:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===============================================================================================================================================================================
-- Description: Function for Businees Rules "Started"    
--
-- Change History:
--	2019-08-16	Sebastián Jaramillo: Function for Businees Rules "Started"
--	2021-08-31	Sebastián Jaramillo: Se adiciona RN VivaAerobus
--	2021-11-10	Sebastián Jaramillo: Se incluye RN Atención AVA - SAI en BOG
--	2021-12-09	Sebastián Jaramillo: Nueva RN American Airlines	
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-03-30	Sebastián Jaramillo: Se ajusta contrato LANCO para cobrar siempre adicional conveyor en ADZ
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
-- ===============================================================================================================================================================================

ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_Starter](
	@HeaderServiceId BIGINT,
	@ServiceTypeId INT, -- it is stage
	@AirportId INT,
	@OriginId INT,
	@DestinationId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@NozzlesNumber INT,
	@DateService DATE
)
RETURNS @T_RESULTADO TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, AdditionalService BIT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150))
AS
BEGIN
	DECLARE	@ExtraText VARCHAR(50) = ''	

	DECLARE @T_TMP_DETALLE_SRV AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@T_TMP_DETALLE_SRV
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			CASE 
				WHEN @NozzlesNumber = 1 THEN 'ARRANCADOR SENCILLO'
				WHEN @NozzlesNumber = 2 THEN 'ARRANCADOR DOBLE'
				WHEN @NozzlesNumber > 1 THEN 'ARRANCADOR ' + CONVERT(NVARCHAR(18), @NozzlesNumber) + ' BOQUILLAS'
				ELSE 'ARRANCADOR #Tipo de Avión sin valor en @asu_nro_boquillas#'
			END,
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) tiempo_total, 
			ISNULL(DS.cantidad, 1) cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 14 AND --ARRANCADOR
			DS.EncabezadoServicioId = @HeaderServiceId

	IF (SELECT SUM(cantidad) FROM @T_TMP_DETALLE_SRV) = 0 RETURN

	IF (@CompanyId=67 AND @BillingToCompany=67) --AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	BEGIN
		IF (@DateService >= '2022-11-01')
		BEGIN
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)

			RETURN
		END
	END

	IF (@CompanyId=272 AND @BillingToCompany=272) --ARAJET / ARAJET
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)

			RETURN
		END
	END

	IF (@CompanyId=259 AND @BillingToCompany=259) --ULTRA AIR / ULTRA AIR
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)

			RETURN
		END
	END

	IF (@CompanyId=43 AND @BillingToCompany=43) --AMERICAN AIRLINES / AMERICAN AIRLINES
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)

			RETURN
		END
	END

	IF (@CompanyId = 51 AND @BillingToCompany = 51) --LANCO
	BEGIN
		IF(@DateService >= '2023-03-03')
		BEGIN
			IF (@AirportId = 5)
			BEGIN
				INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)
				RETURN
			END

			IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
			IF (@ServiceTypeId NOT IN (1)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
			RETURN
		END

		IF(@DateService BETWEEN '2020-02-01' AND '2023-03-02')
		BEGIN
			IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
			IF (@ServiceTypeId NOT IN (1)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
			RETURN
		END
	END

	IF(@CompanyId IN (9, 56)) --COPA                             
	BEGIN
		IF (@DateService <= '2019-06-30')
		BEGIN

			IF (@ServiceTypeId IN(2,3))
			BEGIN
				INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)
				RETURN--OJO!!!!!!
			END
			
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1)
		END
		ELSE
		BEGIN --REGLA VIGENTE A PARTIR DE 2019-07-01
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)
		END

		RETURN
	END

	IF (@CompanyId = 1 AND @BillingToCompany = 87) --AVIANCA A SAI
	BEGIN
		INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)
		RETURN
	END

	IF (@DateService <= '2023-01-31') --SE DESECHA ESTE BLOQUE DE CODIGO OBSOLETO DADO QUE CON TODO EL COMPLEJO DE AVA SE COBRA EL ARRANCADOR ADICIONAL (REGLA POR DEFAULT ABAJO) SE RECONFIRMA COBRO ADICIONAL EN EL "TAKE OFF 20230201" 
	BEGIN
		IF (@DateService <= '2016-03-15')
		BEGIN
			IF(@CompanyId IN (1,193))  --AVIANCA Y REGIONAL EXPRESS AMERICAS               
			BEGIN
				INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1)
				RETURN
			END

			IF(@CompanyId IN (63)) --IBERIA                            
			BEGIN
				INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1)
				RETURN
			END
		END
		ELSE
		BEGIN
			--A PARTIR DEL 2016-03-16 FORMALIZAMOS DE ESTA MANERA
		
			IF (@DateService < '2016-11-16' OR @AirportId IN (11, 40, 31, 25, 43, 47)) --ANTES DEL RFP AVA-2016 'BGA', 'MTR', 'IBE', 'EYP', 'NVA', 'PSO'
			BEGIN
				IF (@CompanyId = 1 AND @BillingToCompany = 1) --AVIANCA A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 47 AND @BillingToCompany = 47) --AEROGAL A AEROGAL
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 42 AND @BillingToCompany = 42) --TACA A TACA 
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 42 AND @BillingToCompany = 54) --TACA A TRANSAMERICAN 
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END
			
				IF (@CompanyId = 41 AND @BillingToCompany = 41) --LACSA A LACSA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 55 AND @BillingToCompany = 1) --JETBLUE A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END
			
				IF (@CompanyId = 38 AND @BillingToCompany = 1) --TAME A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 51 AND @BillingToCompany = 1) --LANCO A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END
			
				IF (@CompanyId = 39 AND @BillingToCompany = 1) --INSEL AIR A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 58 AND @BillingToCompany = 1) --AEROMEXICO A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 65 AND @BillingToCompany = 1) --AEROPOSTAL A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END
			
				IF (@CompanyId = 59 AND @BillingToCompany = 1) --KLM A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

				IF (@CompanyId = 63 AND @BillingToCompany = 1) --IBERIA A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 1) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

			
				IF (@CompanyId = 64 AND @BillingToCompany = 1) --DELTA A AVIANCA
				BEGIN
					IF (@ServiceTypeId = 1) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --TTO 
					IF (@ServiceTypeId = 4) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --PVLO 
					IF (@ServiceTypeId NOT IN (1,4)) INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0)--OTROS
					RETURN
				END

			END
			ELSE
			BEGIN
				IF (@BillingToCompany IN (1, 41, 42, 54, 47)) --AVIANCA, LACSA, TACA, TRANS, AEROGAL
				BEGIN
					INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --SE COBRAN ADICIONALES DE ACUERDO A INSTRUCCION DE GONZALO A 2016-11-30. 
					RETURN
				END
			END
		
		END
	END

	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVACOLOMBIA
	BEGIN
		IF (@DateService BETWEEN '2017-11-01' AND '2020-08-31') --SE MANEJÓ BOLSA
		BEGIN
			RETURN --NO APLICA COBRO POR ESTE LADO DADO QUE SE MANEJA BOLSA A NIVEL NACIONAL
		END

		IF (@DateService >= '2020-09-01') --SE COBRA COMO ADICIONAL OTRO SI COVID
		BEGIN
			IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
			BEGIN
				SET @ExtraText = ' INTERNACIONAL'
			END

			INSERT	@T_RESULTADO 
			SELECT	StartTime
				,	FinalTime
				,	IsAdditionalService
				,	AdditionalAmount
				,	CONCAT(AdditionalService, @ExtraText) AdditionalService
			FROM	CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --SE COBRAN ADICIONALES
			RETURN
		END
	END

	IF (@CompanyId = 192 AND @BillingToCompany = 192) --VIVAPERU
	BEGIN
		RETURN --NO APLICA COBRO POR ESTE LADO DADO QUE SE MANEJA BOLSA A NIVEL NACIONAL
	END

	IF (@CompanyId = 255 AND @BillingToCompany = 255) --VIVAAEROBUS                          
	BEGIN
		IF (@DateService >= '2021-08-21')
		BEGIN
			INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --SE COBRAN ADICIONALES
			RETURN
		END

		RETURN
	END

	INSERT @T_RESULTADO SELECT * FROM CIOServicios.UFN_CIOWeb_CalculateQuantity(@T_TMP_DETALLE_SRV, 0) --TODO SE LES COBRA ADICIONAL
	RETURN
END